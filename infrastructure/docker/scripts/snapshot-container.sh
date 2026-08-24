#!/usr/bin/env bash
set -euo pipefail

readonly version_command_timeout_seconds="${VERSION_REPORT_COMMAND_TIMEOUT_SECONDS:-30}"

spark_version_raw="$(timeout --signal=TERM "${version_command_timeout_seconds}s" spark-submit --version 2>&1)"
hadoop_version_raw="$(timeout --signal=TERM "${version_command_timeout_seconds}s" hadoop version 2>&1)"
java_version_raw="$(timeout --signal=TERM "${version_command_timeout_seconds}s" java -version 2>&1)"
python_version_raw="$(timeout --signal=TERM "${version_command_timeout_seconds}s" python3 --version 2>&1)"

spark_version_normalized="$(printf '%s\n' "${spark_version_raw}" | sed -n 's/.*version \([0-9][0-9.]*\).*/\1/p' | head -n 1)"
hadoop_version_normalized="$(printf '%s\n' "${hadoop_version_raw}" | awk 'NR == 1 {print $2}')"
java_version_normalized="$(printf '%s\n' "${java_version_raw}" | sed -n 's/.*build \([0-9][0-9.+_-]*\).*/\1/p' | head -n 1)"
if [[ -z "${java_version_normalized}" ]]; then
  java_version_normalized="$(printf '%s\n' "${java_version_raw}" | sed -n 's/.*version "\([^"]*\)".*/\1/p' | head -n 1)"
fi
python_version_normalized="$(printf '%s\n' "${python_version_raw}" | awk 'NR == 1 {print $2}')"

[[ -n "${spark_version_normalized}" ]] || { echo "Unable to normalize Spark version from: ${spark_version_raw}" >&2; exit 1; }
[[ -n "${hadoop_version_normalized}" ]] || { echo "Unable to normalize Hadoop version from: ${hadoop_version_raw}" >&2; exit 1; }
[[ -n "${java_version_normalized}" ]] || { echo "Unable to normalize Java build version from: ${java_version_raw}" >&2; exit 1; }
[[ -n "${python_version_normalized}" ]] || { echo "Unable to normalize Python version from: ${python_version_raw}" >&2; exit 1; }

event_log_config="$(awk '$1 == "spark.eventLog.dir" {print $2; exit}' /opt/spark/conf/spark-defaults.conf)"

jq -c -n \
  --arg spark "${spark_version_normalized}" \
  --arg spark_version_normalized "${spark_version_normalized}" \
  --arg spark_version_raw "${spark_version_raw}" \
  --arg hadoop "${hadoop_version_normalized}" \
  --arg hadoop_version_normalized "${hadoop_version_normalized}" \
  --arg hadoop_version_raw "${hadoop_version_raw}" \
  --arg java "${java_version_normalized}" \
  --arg java_version_normalized "${java_version_normalized}" \
  --arg java_version_raw "${java_version_raw}" \
  --arg python "${python_version_normalized}" \
  --arg python_version_normalized "${python_version_normalized}" \
  --arg python_version_raw "${python_version_raw}" \
  --arg timezone "$(date +%Z)" \
  --arg utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg event_log "${event_log_config}" \
  --arg swap_total_kb "$(awk '/SwapTotal/ {print $2}' /proc/meminfo)" \
  --arg swap_free_kb "$(awk '/SwapFree/ {print $2}' /proc/meminfo)" \
  --arg pswpin "$(awk '$1 == "pswpin" {print $2}' /proc/vmstat)" \
  --arg pswpout "$(awk '$1 == "pswpout" {print $2}' /proc/vmstat)" \
  '{
    spark: $spark,
    spark_version_normalized: $spark_version_normalized,
    spark_version_raw: $spark_version_raw,
    hadoop: $hadoop,
    hadoop_version_normalized: $hadoop_version_normalized,
    hadoop_version_raw: $hadoop_version_raw,
    java: $java,
    java_version_normalized: $java_version_normalized,
    java_version_raw: $java_version_raw,
    python: $python,
    python_version_normalized: $python_version_normalized,
    python_version_raw: $python_version_raw,
    timezone: $timezone,
    observed_at_utc: $utc,
    event_log_config: $event_log,
    linux_memory: {
      swap_total_kb: ($swap_total_kb | tonumber),
      swap_free_kb: ($swap_free_kb | tonumber),
      pswpin: ($pswpin | tonumber),
      pswpout: ($pswpout | tonumber)
    }
  }'
