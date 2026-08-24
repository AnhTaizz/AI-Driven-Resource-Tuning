#!/usr/bin/env bash
set -euo pipefail

readonly command_timeout_seconds="${HDFS_VERIFY_COMMAND_TIMEOUT_SECONDS:-30}"
readonly archive_timeout_seconds="${HDFS_VERIFY_ARCHIVE_TIMEOUT_SECONDS:-180}"
readonly artifact="/tmp/local-yarn-v1-health-$RANDOM.txt"
readonly spark_archive_hdfs="/spark/jars/spark-3.5.9-jars.zip"
readonly spark_archive_local="/tmp/local-yarn-v1-spark-archive-$RANDOM.zip"

cleanup() {
  timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -rm -f "${artifact}" >/dev/null 2>&1 || true
  rm -f "${spark_archive_local}"
}
trap cleanup EXIT

if ! report="$(timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfsadmin -report 2>&1)"; then
  echo "Unable to read the HDFS report within ${command_timeout_seconds}s; last observed state: ${report:-no output}" >&2
  exit 1
fi
live_datanodes="$(printf '%s\n' "${report}" | awk '/Live datanodes/ {gsub(/[^0-9]/, "", $3); print $3; exit}')"
if [[ "${live_datanodes:-0}" -ne 2 ]]; then
  echo "Expected exactly 2 live DataNodes, observed ${live_datanodes:-0}; last observed report: ${report}" >&2
  exit 1
fi

printf 'LOCAL_YARN_V1' | timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -put - "${artifact}"
if ! observed="$(timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -cat "${artifact}" 2>&1)"; then
  echo "Unable to read the HDFS round-trip artifact within ${command_timeout_seconds}s; last observed state: ${observed:-no output}" >&2
  exit 1
fi
if [[ "${observed}" != "LOCAL_YARN_V1" ]]; then
  echo "HDFS round-trip content mismatch; last observed content: ${observed}" >&2
  exit 1
fi

if ! archive_get_output="$(timeout --signal=TERM "${archive_timeout_seconds}s" \
    hdfs dfs -get "${spark_archive_hdfs}" "${spark_archive_local}" 2>&1)"; then
  echo "Unable to retrieve ${spark_archive_hdfs} within ${archive_timeout_seconds}s; last observed state: ${archive_get_output:-no output}" >&2
  exit 1
fi
if ! unzip -tqq "${spark_archive_local}"; then
  echo "Spark YARN archive failed ZIP integrity validation: ${spark_archive_hdfs}" >&2
  exit 1
fi
entry_count="$(unzip -Z1 "${spark_archive_local}" | wc -l | tr -d ' ')"
nested_count="$(unzip -Z1 "${spark_archive_local}" | awk 'index($0, "/") > 0 {count++} END {print count+0}')"
non_jar_count="$(unzip -Z1 "${spark_archive_local}" | awk '$0 !~ /[.]jar$/ {count++} END {print count+0}')"
if [[ "${entry_count}" -lt 1 || "${nested_count}" -ne 0 || "${non_jar_count}" -ne 0 ]]; then
  echo "Spark YARN archive must contain only JAR files at its root; entries=${entry_count}, nested=${nested_count}, non_jars=${non_jar_count}" >&2
  exit 1
fi

timeout --signal=TERM "${command_timeout_seconds}s" hdfs dfs -rm "${artifact}" >/dev/null
rm -f "${spark_archive_local}"
trap - EXIT
printf '%s\n' "${report}"
echo "SPARK_YARN_ARCHIVE=hdfs://${spark_archive_hdfs}"
echo "SPARK_YARN_ARCHIVE_ROOT_JAR_COUNT=${entry_count}"
echo "HDFS_VERIFICATION=PASS"
