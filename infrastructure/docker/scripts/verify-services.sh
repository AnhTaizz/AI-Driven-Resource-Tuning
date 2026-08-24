#!/usr/bin/env bash
set -euo pipefail

readonly max_attempts="${SERVICE_VERIFY_MAX_ATTEMPTS:-60}"
readonly poll_interval_seconds="${SERVICE_VERIFY_POLL_INTERVAL_SECONDS:-2}"
readonly curl_connect_timeout_seconds="${SERVICE_VERIFY_CONNECT_TIMEOUT_SECONDS:-2}"
readonly curl_max_time_seconds="${SERVICE_VERIFY_REQUEST_TIMEOUT_SECONDS:-5}"

wait_for_json_service() {
  local service_name="$1"
  local url="$2"
  local jq_filter="$3"
  local attempt
  local response=""
  local last_observed_state="not attempted"

  for ((attempt = 1; attempt <= max_attempts; attempt++)); do
    if response="$(curl --fail --silent --show-error \
        --connect-timeout "${curl_connect_timeout_seconds}" \
        --max-time "${curl_max_time_seconds}" \
        "${url}" 2>&1)"; then
      if printf '%s' "${response}" | jq -e "${jq_filter}" >/dev/null 2>&1; then
        return 0
      fi
      last_observed_state="unexpected response: ${response}"
    else
      last_observed_state="request failed: ${response:-no response}"
    fi
    if (( attempt < max_attempts )); then
      sleep "${poll_interval_seconds}"
    fi
  done

  echo "${service_name} did not become ready after ${max_attempts} attempts; last observed state: ${last_observed_state}" >&2
  return 1
}

wait_for_json_service \
  "NameNode REST" \
  "http://namenode:9870/jmx" \
  '.beans | length > 0'
wait_for_json_service \
  "ResourceManager REST" \
  "http://resourcemanager:8088/ws/v1/cluster/info" \
  '.clusterInfo.state == "STARTED"'
wait_for_json_service \
  "Spark History Server REST" \
  "http://history-server:18080/api/v1/version" \
  '.spark == "3.5.9"'

echo "SERVICE_VERIFICATION=PASS"
