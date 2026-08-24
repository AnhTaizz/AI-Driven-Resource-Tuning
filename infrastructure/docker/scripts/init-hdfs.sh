#!/usr/bin/env bash
set -euo pipefail

readonly spark_archive_local="/tmp/spark-3.5.9-jars.zip"
readonly spark_archive_hdfs="/spark/jars/spark-3.5.9-jars.zip"
readonly max_attempts="${HDFS_INIT_MAX_ATTEMPTS:-60}"
readonly poll_interval_seconds="${HDFS_INIT_POLL_INTERVAL_SECONDS:-2}"
readonly command_timeout_seconds="${HDFS_INIT_COMMAND_TIMEOUT_SECONDS:-30}"
readonly mutation_timeout_seconds="${HDFS_INIT_MUTATION_TIMEOUT_SECONDS:-300}"

cleanup_local_archive() {
  rm -f "${spark_archive_local}"
}
trap cleanup_local_archive EXIT

last_rpc_state="not attempted"
rpc_ready=false
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if last_rpc_state="$(timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfsadmin -safemode get 2>&1)"; then
    rpc_ready=true
    break
  fi
  last_rpc_state="command failed: ${last_rpc_state:-no output}"
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${rpc_ready}" != "true" ]]; then
  echo "NameNode RPC did not become reachable after ${max_attempts} attempts; last observed state: ${last_rpc_state}" >&2
  exit 1
fi

last_datanode_report="not attempted"
live_datanodes=0
datanodes_ready=false
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if last_datanode_report="$(timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfsadmin -report 2>&1)"; then
    live_datanodes="$(printf '%s\n' "${last_datanode_report}" | awk '/Live datanodes/ {gsub(/[^0-9]/, "", $3); print $3; exit}')"
  else
    live_datanodes=0
    last_datanode_report="command failed: ${last_datanode_report:-no output}"
  fi
  if [[ "${live_datanodes:-0}" -eq 2 ]]; then
    datanodes_ready=true
    break
  fi
  if [[ "${live_datanodes:-0}" -gt 2 ]]; then
    echo "Expected exactly 2 live DataNodes, observed ${live_datanodes}; last observed report: ${last_datanode_report}" >&2
    exit 1
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${datanodes_ready}" != "true" ]]; then
  echo "Expected exactly 2 live DataNodes after ${max_attempts} attempts, observed ${live_datanodes:-0}; last observed report: ${last_datanode_report}" >&2
  exit 1
fi

last_safe_mode_state="not attempted"
safe_mode_off=false
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if last_safe_mode_state="$(timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfsadmin -safemode get 2>&1)"; then
    if printf '%s\n' "${last_safe_mode_state}" | grep -Fq 'Safe mode is OFF'; then
      safe_mode_off=true
      break
    fi
  else
    last_safe_mode_state="command failed: ${last_safe_mode_state:-no output}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${safe_mode_off}" != "true" ]]; then
  echo "HDFS did not become writable after ${max_attempts} attempts; last observed safe-mode state: ${last_safe_mode_state}" >&2
  exit 1
fi

timeout --signal=TERM "${mutation_timeout_seconds}s" hdfs dfs -mkdir -p /user/spark /spark-history /spark/jars /yarn-logs /tmp/local-yarn-v1-smoke
timeout --signal=TERM "${mutation_timeout_seconds}s" hdfs dfs -chown -R spark:spark /user/spark /spark-history /spark/jars /yarn-logs /tmp/local-yarn-v1-smoke
timeout --signal=TERM "${mutation_timeout_seconds}s" hdfs dfs -chmod 1777 /spark-history /yarn-logs /tmp/local-yarn-v1-smoke

set +e
timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -test -e "${spark_archive_hdfs}"
archive_test_status="$?"
set -e
if [[ "${archive_test_status}" -eq 1 ]]; then
  rm -f "${spark_archive_local}"
  (
    cd "${SPARK_HOME}/jars"
    zip -q -j "${spark_archive_local}" ./*.jar
  )

  entry_count="$(unzip -Z1 "${spark_archive_local}" | wc -l | tr -d ' ')"
  nested_count="$(unzip -Z1 "${spark_archive_local}" | awk 'index($0, "/") > 0 {count++} END {print count+0}')"
  if [[ "${entry_count}" -lt 1 || "${nested_count}" -ne 0 ]]; then
    echo "Spark YARN ZIP must contain JAR files at archive root" >&2
    exit 1
  fi

  timeout --signal=TERM "${mutation_timeout_seconds}s" hdfs dfs -put "${spark_archive_local}" "${spark_archive_hdfs}"
  rm -f "${spark_archive_local}"
elif [[ "${archive_test_status}" -ne 0 ]]; then
  echo "Unable to determine whether ${spark_archive_hdfs} exists; hdfs dfs -test exited ${archive_test_status}" >&2
  exit "${archive_test_status}"
fi

timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -test -e "${spark_archive_hdfs}"
echo "HDFS initialization complete: ${spark_archive_hdfs}"
