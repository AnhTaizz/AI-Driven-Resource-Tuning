#!/usr/bin/env bash
set -euo pipefail

readonly application_id="${1:?application ID is required}"
readonly rm_url="http://resourcemanager:8088/ws/v1/cluster/apps/${application_id}"
readonly history_list_url="http://history-server:18080/api/v1/applications?status=completed"
readonly history_application_url="http://history-server:18080/api/v1/applications/${application_id}"
readonly max_attempts="${CORRELATION_MAX_ATTEMPTS:-60}"
readonly poll_interval_seconds="${CORRELATION_POLL_INTERVAL_SECONDS:-2}"
readonly curl_connect_timeout_seconds="${CORRELATION_CONNECT_TIMEOUT_SECONDS:-2}"
readonly curl_max_time_seconds="${CORRELATION_REQUEST_TIMEOUT_SECONDS:-5}"
readonly hdfs_command_timeout_seconds="${CORRELATION_HDFS_TIMEOUT_SECONDS:-30}"

rm_complete=false
rm_record=""
last_rm_state="not attempted"
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if rm_record="$(curl --fail --silent --show-error \
      --connect-timeout "${curl_connect_timeout_seconds}" \
      --max-time "${curl_max_time_seconds}" \
      "${rm_url}" 2>&1)"; then
    if printf '%s' "${rm_record}" | jq -e --arg application_id "${application_id}" \
        '.app.id == $application_id' >/dev/null 2>&1; then
      last_rm_state="$(printf '%s' "${rm_record}" | jq -c \
        '{id: .app.id, state: .app.state, finalStatus: .app.finalStatus, diagnostics: .app.diagnostics}')"
      rm_state="$(printf '%s' "${rm_record}" | jq -r '.app.state')"
      rm_final_status="$(printf '%s' "${rm_record}" | jq -r '.app.finalStatus')"
      if [[ "${rm_state}" == "FINISHED" ]]; then
        if [[ "${rm_final_status}" != "SUCCEEDED" ]]; then
          echo "YARN application ${application_id} finished without success; last observed state: ${last_rm_state}" >&2
          exit 1
        fi
        rm_complete=true
        break
      fi
      if [[ "${rm_state}" == "FAILED" || "${rm_state}" == "KILLED" ]]; then
        echo "YARN application ${application_id} reached terminal state ${rm_state}; last observed state: ${last_rm_state}" >&2
        exit 1
      fi
    else
      last_rm_state="unexpected response: ${rm_record}"
    fi
  else
    last_rm_state="request failed: ${rm_record:-no response}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${rm_complete}" != "true" ]]; then
  echo "YARN application ${application_id} did not reach FINISHED/SUCCEEDED after ${max_attempts} attempts; last observed state: ${last_rm_state}" >&2
  exit 1
fi

history_found=false
history_record=""
last_history_state="not attempted"
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if history_record="$(curl --fail --silent --show-error \
      --connect-timeout "${curl_connect_timeout_seconds}" \
      --max-time "${curl_max_time_seconds}" \
      "${history_list_url}" 2>&1)"; then
    if printf '%s' "${history_record}" | jq -e --arg application_id "${application_id}" \
        'any(.[]?; .id == $application_id)' >/dev/null 2>&1; then
      history_found=true
      last_history_state="application listed as completed"
      break
    fi
    last_history_state="completed application IDs: $(printf '%s' "${history_record}" | jq -c '[.[]?.id]' 2>/dev/null || printf '%s' "invalid JSON: ${history_record}")"
  else
    last_history_state="request failed: ${history_record:-no response}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${history_found}" != "true" ]]; then
  echo "History Server did not list ${application_id} after ${max_attempts} attempts; last observed state: ${last_history_state}" >&2
  exit 1
fi

history_attempt_id="$(printf '%s' "${history_record}" | jq -r \
  --arg application_id "${application_id}" \
  '[.[]? | select(.id == $application_id)][0].attempts[0].attemptId // empty')"
if [[ -n "${history_attempt_id}" ]]; then
  history_environment_url="${history_application_url}/${history_attempt_id}/environment"
else
  history_environment_url="${history_application_url}/environment"
fi

environment_found=false
environment_record=""
last_environment_state="not attempted"
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if environment_record="$(curl --fail --silent --show-error \
      --connect-timeout "${curl_connect_timeout_seconds}" \
      --max-time "${curl_max_time_seconds}" \
      "${history_environment_url}" 2>&1)"; then
    if printf '%s' "${environment_record}" | jq -e '.sparkProperties | type == "array"' >/dev/null 2>&1; then
      environment_found=true
      last_environment_state="Spark environment record available"
      break
    fi
    last_environment_state="unexpected response: ${environment_record}"
  else
    last_environment_state="request failed: ${environment_record:-no response}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${environment_found}" != "true" ]]; then
  echo "History Server environment was unavailable for ${application_id} after ${max_attempts} attempts; last observed state: ${last_environment_state}" >&2
  exit 1
fi

if ! printf '%s' "${environment_record}" | jq -e '
    def spark_property($key):
      [.sparkProperties[]? | select(.[0] == $key) | .[1]] | last;
    spark_property("spark.dynamicAllocation.enabled") == "false" and
    spark_property("spark.sql.adaptive.enabled") == "false" and
    spark_property("spark.sql.shuffle.partitions") == "4" and
    spark_property("spark.executor.instances") == "2" and
    spark_property("spark.executor.cores") == "1" and
    spark_property("spark.executor.memory") == "512m" and
    spark_property("spark.executor.memoryOverhead") == "384m" and
    spark_property("spark.driver.memory") == "512m" and
    spark_property("spark.driver.memoryOverhead") == "384m" and
    spark_property("spark.master") == "yarn" and
    spark_property("spark.submit.deployMode") == "cluster" and
    spark_property("spark.eventLog.enabled") == "true" and
    spark_property("spark.eventLog.dir") == "hdfs:///spark-history" and
    spark_property("spark.yarn.archive") == "hdfs:///spark/jars/spark-3.5.9-jars.zip"
  ' >/dev/null; then
  observed_properties="$(printf '%s' "${environment_record}" | jq -c '
    [.sparkProperties[]?
      | select(.[0] == "spark.dynamicAllocation.enabled" or
               .[0] == "spark.sql.adaptive.enabled" or
               .[0] == "spark.sql.shuffle.partitions" or
               .[0] == "spark.executor.instances" or
               .[0] == "spark.executor.cores" or
               .[0] == "spark.executor.memory" or
               .[0] == "spark.executor.memoryOverhead" or
               .[0] == "spark.driver.memory" or
               .[0] == "spark.driver.memoryOverhead" or
               .[0] == "spark.master" or
               .[0] == "spark.submit.deployMode" or
               .[0] == "spark.eventLog.enabled" or
               .[0] == "spark.eventLog.dir" or
               .[0] == "spark.yarn.archive")]
  ' 2>/dev/null || printf '%s' "invalid JSON: ${environment_record}")"
  echo "Spark History Server effective configuration did not match the infrastructure smoke contract; last observed properties: ${observed_properties}" >&2
  exit 1
fi

event_log_found=false
event_log_listing=""
last_event_log_state="not attempted"
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if event_log_listing="$(timeout --signal=TERM "${hdfs_command_timeout_seconds}s" hdfs dfs -ls /spark-history 2>&1)"; then
    if printf '%s\n' "${event_log_listing}" | grep -Fq "${application_id}"; then
      event_log_found=true
      break
    fi
    last_event_log_state="application ID absent from listing: ${event_log_listing}"
  else
    last_event_log_state="listing failed: ${event_log_listing:-no output}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${event_log_found}" != "true" ]]; then
  echo "HDFS event log for ${application_id} was not found after ${max_attempts} attempts; last observed state: ${last_event_log_state}" >&2
  exit 1
fi

effective_properties="$(printf '%s' "${environment_record}" | jq -c '
  [.sparkProperties[]?
    | select(.[0] == "spark.dynamicAllocation.enabled" or
             .[0] == "spark.sql.adaptive.enabled" or
             .[0] == "spark.sql.shuffle.partitions" or
             .[0] == "spark.executor.instances" or
             .[0] == "spark.executor.cores" or
             .[0] == "spark.executor.memory" or
             .[0] == "spark.executor.memoryOverhead" or
             .[0] == "spark.driver.memory" or
             .[0] == "spark.driver.memoryOverhead" or
             .[0] == "spark.master" or
             .[0] == "spark.submit.deployMode" or
             .[0] == "spark.eventLog.enabled" or
             .[0] == "spark.eventLog.dir" or
             .[0] == "spark.yarn.archive")]
')"
history_application="$(printf '%s' "${history_record}" | jq -c \
  --arg application_id "${application_id}" \
  '[.[]? | select(.id == $application_id)] | first')"

echo "CORRELATED_APPLICATION_ID=${application_id}"
echo "CORRELATED_SPARK_ATTEMPT_ID=${history_attempt_id:-none}"
echo "OBSERVED_YARN_APPLICATION=${last_rm_state}"
echo "OBSERVED_SPARK_PROPERTIES=${effective_properties}"
printf '%s\n' "${history_application}" | jq .
printf '%s\n' "${environment_record}" | jq .
printf '%s\n' "${event_log_listing}"
echo "CORRELATION_VERIFICATION=PASS"
