#!/usr/bin/env bash
set -euo pipefail

readonly classification="INFRASTRUCTURE_OBSERVABILITY_ONLY"
readonly observation_seconds="${1:-180}"
readonly min_observation_seconds=30
readonly max_observation_seconds=600
readonly source_root="/opt/local-yarn/observability-source"
readonly source_file="${source_root}/src/main/java/localyarn/LocalYarnObservability.java"
readonly rm_internal_base="http://resourcemanager:8088"
readonly history_internal_base="http://history-server:18080"
readonly host_rm_port="${HOST_RESOURCE_MANAGER_PORT:-8088}"
readonly host_history_port="${HOST_HISTORY_SERVER_PORT:-18080}"
readonly application_name="LOCAL_YARN_V1_OBSERVABILITY_TEST"
readonly application_poll_attempts=120
readonly history_poll_attempts=60
readonly history_validation_timeout_seconds=180

if [[ ! "${observation_seconds}" =~ ^[0-9]+$ ]] \
    || (( observation_seconds < min_observation_seconds )) \
    || (( observation_seconds > max_observation_seconds )); then
  echo "ObservationSeconds must be an integer from ${min_observation_seconds} through ${max_observation_seconds}." >&2
  exit 2
fi
if [[ ! -r "${source_file}" ]]; then
  echo "Missing read-only observability source: ${source_file}" >&2
  exit 2
fi

work_dir="$(mktemp -d /tmp/local-yarn-observability.XXXXXX)"
classes_dir="${work_dir}/classes"
job_jar="${work_dir}/local-yarn-observability.jar"
submit_log="${work_dir}/spark-submit.log"
application_id=""
submit_pid=""
tail_pid=""
submission_started_epoch_ms=0
completed_successfully=false

cleanup() {
  local exit_code=$?
  trap - EXIT INT TERM

  if [[ -n "${tail_pid}" ]] && kill -0 "${tail_pid}" >/dev/null 2>&1; then
    kill "${tail_pid}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${submit_pid}" ]] && kill -0 "${submit_pid}" >/dev/null 2>&1; then
    kill "${submit_pid}" >/dev/null 2>&1 || true
  fi
  if [[ -z "${application_id}" && -r "${submit_log}" ]]; then
    application_id="$(grep -Eo 'application_[0-9]+_[0-9]+' "${submit_log}" | head -n 1 || true)"
  fi
  if [[ -z "${application_id}" && "${submission_started_epoch_ms}" -gt 0 ]]; then
    cleanup_applications="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/ws/v1/cluster/apps?applicationTypes=SPARK&states=NEW,NEW_SAVING,SUBMITTED,ACCEPTED,RUNNING" \
      2>/dev/null || true)"
    application_id="$(printf '%s' "${cleanup_applications}" | jq -r \
      --arg application_name "${application_name}" \
      --argjson submitted_after "${submission_started_epoch_ms}" '
        def as_array: if type == "array" then . elif . == null then [] else [.] end;
        [((.apps.app // null) | as_array)[]
          | select(.name == $application_name and .startedTime >= $submitted_after)]
        | if length == 1 then .[0].id else empty end
      ' 2>/dev/null || true)"
  fi
  if [[ "${completed_successfully}" != "true" && -n "${application_id}" ]]; then
    timeout --signal=TERM 30s yarn application -kill "${application_id}" >/dev/null 2>&1 || true
    for ((cleanup_attempt = 1; cleanup_attempt <= 15; cleanup_attempt++)); do
      cleanup_record="$(curl --fail --silent --show-error --location \
        --connect-timeout 2 --max-time 5 \
        "${rm_internal_base}/ws/v1/cluster/apps/${application_id}" 2>/dev/null || true)"
      cleanup_state="$(printf '%s' "${cleanup_record}" | jq -r '.app.state // empty' 2>/dev/null || true)"
      if [[ "${cleanup_state}" == "FINISHED" || "${cleanup_state}" == "FAILED" || "${cleanup_state}" == "KILLED" ]]; then
        break
      fi
      sleep 2
    done
  fi
  rm -rf -- "${work_dir}"
  exit "${exit_code}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

mkdir -p "${classes_dir}"
javac --release 11 \
  -classpath '/opt/spark/jars/*' \
  -d "${classes_dir}" \
  "${source_file}"
jar --create \
  --file "${job_jar}" \
  --main-class localyarn.LocalYarnObservability \
  -C "${classes_dir}" .

echo "OBSERVABILITY_CLASSIFICATION=${classification}"
echo "OBSERVABILITY_NOT_BENCHMARK=true"
echo "OBSERVABILITY_NOT_ML_DATA=true"
echo "OBSERVABILITY_SOURCE_MOUNT=READ_ONLY"
echo "OBSERVABILITY_SECONDS=${observation_seconds}"
echo "Waiting for YARN to assign the application ID..."

: > "${submit_log}"
readonly submit_timeout_seconds=$((observation_seconds + 600))
submission_started_epoch_ms="$(date -u +%s%3N)"
timeout --signal=TERM --kill-after=30s "${submit_timeout_seconds}s" spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --name "${application_name}" \
  --class localyarn.LocalYarnObservability \
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
  --conf spark.yarn.submit.waitAppCompletion=true \
  --conf spark.yarn.tags=LOCAL_YARN_V1,INFRASTRUCTURE_OBSERVABILITY_TEST \
  --conf spark.ui.killEnabled=false \
  --conf spark.ui.prometheus.enabled=true \
  --conf spark.eventLog.logStageExecutorMetrics=true \
  --conf spark.executor.metrics.pollingInterval=1000 \
  --conf spark.executor.processTreeMetrics.enabled=true \
  "${job_jar}" \
  "${observation_seconds}" >"${submit_log}" 2>&1 &
submit_pid=$!
tail --pid="${submit_pid}" --lines=+1 --follow=name "${submit_log}" &
tail_pid=$!

for ((attempt = 1; attempt <= application_poll_attempts; attempt++)); do
  application_id="$(grep -Eo 'application_[0-9]+_[0-9]+' "${submit_log}" | head -n 1 || true)"
  if [[ -n "${application_id}" ]]; then
    break
  fi
  if ! kill -0 "${submit_pid}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if [[ -z "${application_id}" ]]; then
  echo "No YARN application ID was observed after ${application_poll_attempts} bounded polling attempts." >&2
  exit 1
fi

yarn_state=""
last_yarn_record=""
for ((attempt = 1; attempt <= application_poll_attempts; attempt++)); do
  if last_yarn_record="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/ws/v1/cluster/apps/${application_id}" 2>/dev/null)"; then
    yarn_state="$(printf '%s' "${last_yarn_record}" | jq -r '.app.state // empty')"
    if [[ "${yarn_state}" == "RUNNING" ]]; then
      break
    fi
    if [[ "${yarn_state}" == "FINISHED" || "${yarn_state}" == "FAILED" || "${yarn_state}" == "KILLED" ]]; then
      echo "Application reached ${yarn_state} before the live observation window became available." >&2
      exit 1
    fi
  fi
  sleep 1
done
if [[ "${yarn_state}" != "RUNNING" ]]; then
  echo "YARN did not report RUNNING after ${application_poll_attempts} bounded polling attempts; last state=${yarn_state:-missing}." >&2
  exit 1
fi

live_applications=""
live_application_count=0
for ((attempt = 1; attempt <= application_poll_attempts; attempt++)); do
  if live_applications="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/proxy/${application_id}/api/v1/applications" 2>/dev/null)"; then
    live_application_count="$(printf '%s' "${live_applications}" | jq -r \
      --arg application_id "${application_id}" \
      '[.[] | select(.id == $application_id)] | length' 2>/dev/null || printf '0')"
    if (( live_application_count == 1 )); then
      break
    fi
  fi
  sleep 1
done
if (( live_application_count != 1 )); then
  echo "The live Spark REST API did not expose exactly one matching application after ${application_poll_attempts} bounded polling attempts." >&2
  exit 1
fi

readonly live_spark_application_key="${application_id}"
readonly live_spark_api_base="${rm_internal_base}/proxy/${application_id}/api/v1/applications/${live_spark_application_key}"
executor_records=0
prometheus_body=""
prometheus_worker_executors=0
live_yarn_state=""
live_application_incomplete=false
for ((attempt = 1; attempt <= application_poll_attempts; attempt++)); do
  live_executors="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${live_spark_api_base}/executors" 2>/dev/null || true)"
  executor_records="$(printf '%s' "${live_executors}" | jq -r \
      'if type == "array" then [.[] | select(.id != "driver")] | length else 0 end' \
      2>/dev/null || printf '0')"
  worker_executor_ids="$(printf '%s' "${live_executors}" | jq -r \
      'if type == "array" then .[] | select(.id != "driver") | .id else empty end' \
      2>/dev/null || true)"
  prometheus_body="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/proxy/${application_id}/metrics/executors/prometheus" 2>/dev/null || true)"
  prometheus_samples="$(printf '%s\n' "${prometheus_body}" | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d')"
  prometheus_worker_executors=0
  if [[ -n "${worker_executor_ids}" ]]; then
    while IFS= read -r executor_id; do
      if [[ -n "${executor_id}" ]] \
          && grep -Fq "executor_id=\"${executor_id}\"" <<< "${prometheus_samples}"; then
        prometheus_worker_executors=$((prometheus_worker_executors + 1))
      fi
    done <<< "${worker_executor_ids}"
  fi

  live_applications="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/proxy/${application_id}/api/v1/applications" 2>/dev/null || true)"
  live_application_incomplete="$(printf '%s' "${live_applications}" | jq -r \
      --arg application_id "${application_id}" '
        [.[] | select(.id == $application_id and .attempts[0].completed == false)]
        | length == 1
      ' 2>/dev/null || printf 'false')"
  last_yarn_record="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/ws/v1/cluster/apps/${application_id}" 2>/dev/null || true)"
  live_yarn_state="$(printf '%s' "${last_yarn_record}" | jq -r '.app.state // empty' 2>/dev/null || true)"

  if [[ "${live_yarn_state}" == "RUNNING" \
      && "${live_application_incomplete}" == "true" \
      && "${executor_records}" -ge 2 \
      && "${prometheus_worker_executors}" -eq "${executor_records}" ]]; then
    break
  fi
  if [[ "${live_yarn_state}" == "FINISHED" || "${live_yarn_state}" == "FAILED" || "${live_yarn_state}" == "KILLED" ]]; then
    break
  fi
  sleep 1
done
if [[ "${live_yarn_state}" != "RUNNING" || "${live_application_incomplete}" != "true" ]]; then
  echo "Live monitoring was not correlated with an incomplete RUNNING YARN application; YARN=${live_yarn_state:-missing}, Spark incomplete=${live_application_incomplete}." >&2
  exit 1
fi
if (( executor_records < 2 )); then
  echo "Live Spark REST exposed only ${executor_records} worker executor record(s); expected at least two." >&2
  exit 1
fi
if (( prometheus_worker_executors != executor_records )); then
  echo "Prometheus exposed samples for ${prometheus_worker_executors} of ${executor_records} observed worker executors." >&2
  exit 1
fi

echo "OBSERVED_APPLICATION_ID=${application_id}"
echo "YARN_STATE=${yarn_state}"
echo "LIVE_SPARK_REST_KEY=${live_spark_application_key}"
echo "LIVE_WORKER_EXECUTOR_RECORDS=${executor_records}"
echo "LIVE_PROMETHEUS_WORKER_EXECUTORS=${prometheus_worker_executors}"
echo "YARN_APPLICATION_UI=http://127.0.0.1:${host_rm_port}/cluster/app/${application_id}"
echo "YARN_APPLICATION_REST=http://127.0.0.1:${host_rm_port}/ws/v1/cluster/apps/${application_id}"
echo "LIVE_SPARK_UI=http://127.0.0.1:${host_rm_port}/proxy/${application_id}/"
echo "LIVE_SPARK_EXECUTORS_REST=http://127.0.0.1:${host_rm_port}/proxy/${application_id}/api/v1/applications/${live_spark_application_key}/executors"
echo "LIVE_SPARK_PROMETHEUS=http://127.0.0.1:${host_rm_port}/proxy/${application_id}/metrics/executors/prometheus"
echo "HISTORY_SERVER_APPLICATION_AFTER_COMPLETION=http://127.0.0.1:${host_history_port}/api/v1/applications/${application_id}"
echo "Keep this terminal open; the job will finish after its bounded observation window."

set +e
wait "${submit_pid}"
submit_status=$?
set -e
submit_pid=""
if [[ -n "${tail_pid}" ]]; then
  wait "${tail_pid}" >/dev/null 2>&1 || true
  tail_pid=""
fi
if (( submit_status != 0 )); then
  echo "spark-submit failed with exit code ${submit_status}." >&2
  exit "${submit_status}"
fi

final_yarn_state=""
final_yarn_status=""
for ((attempt = 1; attempt <= application_poll_attempts; attempt++)); do
  if last_yarn_record="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${rm_internal_base}/ws/v1/cluster/apps/${application_id}" 2>/dev/null)"; then
    final_yarn_state="$(printf '%s' "${last_yarn_record}" | jq -r '.app.state // empty')"
    final_yarn_status="$(printf '%s' "${last_yarn_record}" | jq -r '.app.finalStatus // empty')"
    if [[ "${final_yarn_state}" == "FINISHED" ]]; then
      break
    fi
  fi
  sleep 1
done
if [[ "${final_yarn_state}" != "FINISHED" || "${final_yarn_status}" != "SUCCEEDED" ]]; then
  echo "Unexpected final YARN result: state=${final_yarn_state:-missing}, finalStatus=${final_yarn_status:-missing}." >&2
  exit 1
fi

history_application=""
history_attempt_id=""
for ((attempt = 1; attempt <= history_poll_attempts; attempt++)); do
  if history_application="$(curl --fail --silent --show-error --location \
      --connect-timeout 2 --max-time 5 \
      "${history_internal_base}/api/v1/applications/${application_id}" 2>/dev/null)"; then
    history_attempt_id="$(printf '%s' "${history_application}" | jq -r \
      '[.attempts[] | select(.completed == true)][0].attemptId // empty' 2>/dev/null || true)"
    if [[ -n "${history_attempt_id}" ]]; then
      break
    fi
  fi
  sleep 1
done
if [[ -z "${history_attempt_id}" ]]; then
  echo "Spark History Server did not expose a completed attempt after ${history_poll_attempts} bounded polling attempts." >&2
  exit 1
fi
readonly history_api_base="${history_internal_base}/api/v1/applications/${application_id}/${history_attempt_id}"
readonly history_validation_deadline=$((SECONDS + history_validation_timeout_seconds))

assert_history_json() {
  local history_endpoint="$1"
  local jq_filter="$2"
  local description="$3"
  local history_payload=""
  while (( SECONDS < history_validation_deadline )); do
    if history_payload="$(curl --fail --silent --show-error --location \
        --connect-timeout 2 --max-time 30 \
        "${history_api_base}/${history_endpoint}" 2>/dev/null)" \
        && printf '%s' "${history_payload}" | jq -e "${jq_filter}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "History endpoint ${history_endpoint} did not contain ${description} before the shared ${history_validation_timeout_seconds}-second validation deadline." >&2
  exit 1
}

assert_history_json 'jobs' 'type == "array" and length > 0' 'at least one job record'
assert_history_json 'stages?withSummaries=true' 'type == "array" and length > 0' 'at least one stage record'
assert_history_json 'allexecutors' 'type == "array" and ([.[] | select(.id != "driver")] | length) >= 2' 'at least two worker executor records'
assert_history_json 'sql' 'type == "array" and length > 0' 'at least one SQL execution record'
assert_history_json 'environment' '
  type == "object"
  and (.sparkProperties | type == "array")
  and any(.sparkProperties[]; .[0] == "spark.master" and .[1] == "yarn")
  and any(.sparkProperties[]; .[0] == "spark.dynamicAllocation.enabled" and .[1] == "false")
  and any(.sparkProperties[]; .[0] == "spark.sql.adaptive.enabled" and .[1] == "false")
  and any(.sparkProperties[]; .[0] == "spark.ui.prometheus.enabled" and .[1] == "true")
' 'the expected effective Spark properties'

completed_successfully=true
echo "YARN_FINAL_STATE=${final_yarn_state}"
echo "YARN_FINAL_STATUS=${final_yarn_status}"
echo "HISTORY_COMPLETED_ATTEMPT=${history_attempt_id}"
echo "HISTORY_SERVER_UI=http://127.0.0.1:${host_history_port}/history/${application_id}/${history_attempt_id}/"
echo "HISTORY_SERVER_API=http://127.0.0.1:${host_history_port}/api/v1/applications/${application_id}/${history_attempt_id}"
echo "LIVE_SPARK_REST_CHECK=PASS"
echo "LIVE_EXECUTOR_PROMETHEUS_CHECK=PASS"
echo "HISTORY_SERVER_REST_CHECK=PASS"
echo "OBSERVABILITY_TEST_RESULT=PASS"
