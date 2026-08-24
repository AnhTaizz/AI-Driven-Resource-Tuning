#!/usr/bin/env bash
set -euo pipefail

readonly run_id="$(date -u +%Y%m%dT%H%M%S%NZ)-$$-${RANDOM}"
readonly output_path="hdfs:///tmp/local-yarn-v1-smoke/${run_id}"
readonly submit_log="/tmp/local-yarn-v1-spark-submit-${run_id}.log"
readonly submit_timeout_seconds="${SPARK_SUBMIT_TIMEOUT_SECONDS:-900}"
readonly command_timeout_seconds="${SPARK_VERIFY_COMMAND_TIMEOUT_SECONDS:-30}"
readonly curl_connect_timeout_seconds="${SPARK_VERIFY_CONNECT_TIMEOUT_SECONDS:-2}"
readonly curl_max_time_seconds="${SPARK_VERIFY_REQUEST_TIMEOUT_SECONDS:-5}"
readonly cleanup_max_attempts="${SPARK_CLEANUP_MAX_ATTEMPTS:-15}"
readonly cleanup_poll_interval_seconds="${SPARK_CLEANUP_POLL_INTERVAL_SECONDS:-2}"

cleanup() {
  timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -rm -r -f "${output_path}" >/dev/null 2>&1 || true
  rm -f "${submit_log}"
}
trap cleanup EXIT

terminate_submitted_application() {
  local target_application_id="$1"
  local kill_output=""
  local rm_record=""
  local rm_state=""
  local last_cleanup_state="kill not attempted"

  if ! kill_output="$(timeout --signal=TERM "${command_timeout_seconds}s" \
      yarn application -kill "${target_application_id}" 2>&1)"; then
    last_cleanup_state="kill command failed: ${kill_output:-no output}"
  else
    last_cleanup_state="kill requested: ${kill_output:-no output}"
  fi

  for ((cleanup_attempt = 1; cleanup_attempt <= cleanup_max_attempts; cleanup_attempt++)); do
    if rm_record="$(curl --fail --silent --show-error \
        --connect-timeout "${curl_connect_timeout_seconds}" \
        --max-time "${curl_max_time_seconds}" \
        "http://resourcemanager:8088/ws/v1/cluster/apps/${target_application_id}" 2>&1)"; then
      rm_state="$(printf '%s' "${rm_record}" | jq -r '.app.state // "UNKNOWN"' 2>/dev/null || printf 'INVALID_JSON')"
      last_cleanup_state="$(printf '%s' "${rm_record}" | jq -c \
        '{id: .app.id, state: .app.state, finalStatus: .app.finalStatus, diagnostics: .app.diagnostics}' \
        2>/dev/null || printf '%s' "invalid JSON: ${rm_record}")"
      if [[ "${rm_state}" == "FINISHED" || "${rm_state}" == "FAILED" || "${rm_state}" == "KILLED" ]]; then
        echo "YARN failure cleanup reached terminal state for ${target_application_id}: ${last_cleanup_state}" >&2
        return 0
      fi
    else
      last_cleanup_state="ResourceManager cleanup poll failed: ${rm_record:-no response}"
    fi
    if (( cleanup_attempt < cleanup_max_attempts )); then
      sleep "${cleanup_poll_interval_seconds}"
    fi
  done

  echo "Unable to confirm terminal cleanup for ${target_application_id} after ${cleanup_max_attempts} attempts; last observed state: ${last_cleanup_state}" >&2
  return 0
}

set +e
timeout --signal=TERM --kill-after=30s "${submit_timeout_seconds}s" spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --name LOCAL_YARN_V1_INFRASTRUCTURE_SMOKE \
  --class localyarn.LocalYarnSmoke \
  --num-executors 2 \
  --executor-cores 1 \
  --executor-memory 512m \
  --driver-memory 512m \
  --conf spark.executor.memoryOverhead=384m \
  --conf spark.driver.memoryOverhead=384m \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.sql.adaptive.enabled=false \
  --conf spark.sql.shuffle.partitions=4 \
  --conf spark.yarn.maxAppAttempts=1 \
  --conf spark.yarn.tags=LOCAL_YARN_V1,INFRASTRUCTURE_SMOKE_TEST \
  /opt/local-yarn/smoke/local-yarn-smoke.jar \
  "${output_path}" 2>&1 | tee "${submit_log}"
pipeline_status=("${PIPESTATUS[@]}")
set -e

submit_status="${pipeline_status[0]}"
tee_status="${pipeline_status[1]}"
application_id="$(grep -Eo 'application_[0-9]+_[0-9]+' "${submit_log}" | head -n 1 || true)"
if [[ -n "${application_id}" ]]; then
  echo "OBSERVED_APPLICATION_ID=${application_id}"
fi

last_application_state="application ID was not observed"
if [[ -n "${application_id}" ]]; then
  rm_record=""
  if rm_record="$(curl --fail --silent --show-error \
      --connect-timeout "${curl_connect_timeout_seconds}" \
      --max-time "${curl_max_time_seconds}" \
      "http://resourcemanager:8088/ws/v1/cluster/apps/${application_id}" 2>&1)"; then
    last_application_state="$(printf '%s' "${rm_record}" | jq -c \
      '{id: .app.id, state: .app.state, finalStatus: .app.finalStatus, diagnostics: .app.diagnostics}' \
      2>/dev/null || printf '%s' "invalid JSON: ${rm_record}")"
  else
    last_application_state="ResourceManager request failed: ${rm_record:-no response}"
  fi
fi

if [[ "${submit_status}" -ne 0 || "${tee_status}" -ne 0 ]]; then
  if [[ -n "${application_id}" ]]; then
    terminate_submitted_application "${application_id}"
  else
    echo "Cannot clean up a potentially submitted YARN application because no application ID was observed." >&2
  fi
fi

if [[ "${tee_status}" -ne 0 ]]; then
  echo "Unable to preserve spark-submit output: tee exited ${tee_status}; application=${application_id:-not observed}; last observed state: ${last_application_state}" >&2
  exit "${tee_status}"
fi
if [[ "${submit_status}" -eq 124 ]]; then
  echo "spark-submit did not complete within ${submit_timeout_seconds}s; application=${application_id:-not observed}; last observed state: ${last_application_state}" >&2
  exit 124
fi
if [[ "${submit_status}" -ne 0 ]]; then
  echo "spark-submit failed with exit code ${submit_status}; application=${application_id:-not observed}; last observed state: ${last_application_state}" >&2
  exit "${submit_status}"
fi

if [[ -z "${application_id}" ]]; then
  echo "No YARN application ID was observed in completed spark-submit output; last observed state: ${last_application_state}" >&2
  exit 1
fi

if ! timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -test -e "${output_path}/_SUCCESS"; then
  echo "Spark smoke output did not contain _SUCCESS within ${command_timeout_seconds}s; application=${application_id}; output=${output_path}" >&2
  exit 1
fi
/opt/local-yarn/bin/verify-correlation.sh "${application_id}"

echo "APPLICATION_ID=${application_id}"
echo "SMOKE_CLASSIFICATION=INFRASTRUCTURE_VERIFICATION_ONLY"
echo "SPARK_SMOKE_VERIFICATION=PASS"
