#!/usr/bin/env bash
set -euo pipefail

readonly rm_base_url="http://resourcemanager:8088/ws/v1/cluster"
readonly max_attempts="${YARN_VERIFY_MAX_ATTEMPTS:-60}"
readonly poll_interval_seconds="${YARN_VERIFY_POLL_INTERVAL_SECONDS:-2}"
readonly curl_connect_timeout_seconds="${YARN_VERIFY_CONNECT_TIMEOUT_SECONDS:-2}"
readonly curl_max_time_seconds="${YARN_VERIFY_REQUEST_TIMEOUT_SECONDS:-5}"
readonly yarn_site_path="/opt/hadoop/etc/hadoop/yarn-site.xml"
readonly expected_calculator="org.apache.hadoop.yarn.util.resource.DominantResourceCalculator"
readonly expected_scheduler="org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler"

last_nodes_state="not attempted"
nodes_json=""
nodes_ready=false
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if nodes_json="$(curl --fail --silent --show-error \
      --connect-timeout "${curl_connect_timeout_seconds}" \
      --max-time "${curl_max_time_seconds}" \
      "${rm_base_url}/nodes" 2>&1)"; then
    last_nodes_state="$(printf '%s' "${nodes_json}" | jq -c \
      '[.nodes.node[]? | {id, nodeHostName, state, usedMemoryMB, availMemoryMB, usedVirtualCores, availableVirtualCores}]' \
      2>&1 || printf '%s' "invalid JSON: ${nodes_json}")"
    running_nodes="$(printf '%s' "${nodes_json}" | jq \
      '[.nodes.node[]? | select(.state == "RUNNING")] | length' 2>/dev/null || printf '0')"
    total_nodes="$(printf '%s' "${nodes_json}" | jq '[.nodes.node[]?] | length' 2>/dev/null || printf '0')"
    if [[ "${total_nodes}" -gt 2 ]]; then
      echo "Expected exactly 2 registered NodeManagers, observed ${total_nodes}; last observed state: ${last_nodes_state}" >&2
      exit 1
    fi
    resource_fields_present="$(printf '%s' "${nodes_json}" | jq -r '
      [.nodes.node[]?] | (length == 2 and all(.[];
        has("usedMemoryMB") and (.usedMemoryMB | type) == "number" and
        has("availMemoryMB") and (.availMemoryMB | type) == "number" and
        has("usedVirtualCores") and (.usedVirtualCores | type) == "number" and
        has("availableVirtualCores") and (.availableVirtualCores | type) == "number"
      ))
    ' 2>/dev/null || printf 'false')"
    if [[ "${total_nodes}" -eq 2 && "${resource_fields_present}" != "true" ]]; then
      echo "YARN node REST evidence omitted or mis-typed a required resource field; observed nodes: ${last_nodes_state}" >&2
      exit 1
    fi
    resources_ready="$(printf '%s' "${nodes_json}" | jq -r '
      [.nodes.node[]?
        | {
            state: .state,
            total_memory_mb: (.usedMemoryMB + .availMemoryMB),
            total_vcores: (.usedVirtualCores + .availableVirtualCores)
          }
      ] | (length == 2 and all(.[]; .state == "RUNNING" and .total_memory_mb == 2048 and .total_vcores == 2))
    ' 2>/dev/null || printf 'false')"
    if [[ "${running_nodes}" -eq 2 && "${total_nodes}" -eq 2 && "${resources_ready}" == "true" ]]; then
      nodes_ready=true
      break
    fi
  else
    last_nodes_state="request failed: ${nodes_json:-no response}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${nodes_ready}" != "true" ]]; then
  echo "Expected 2 RUNNING NodeManagers advertising 2048 MB and 2 vcores each after ${max_attempts} attempts; last observed state: ${last_nodes_state}" >&2
  exit 1
fi

observed_nodes="$(printf '%s' "${nodes_json}" | jq -c '
  [.nodes.node[]
    | {
        node_id: .id,
        node_host_name: .nodeHostName,
        state: .state,
        used_memory_mb: .usedMemoryMB,
        available_memory_mb: .availMemoryMB,
        total_memory_mb: (.usedMemoryMB + .availMemoryMB),
        used_vcores: .usedVirtualCores,
        available_vcores: .availableVirtualCores,
        total_vcores: (.usedVirtualCores + .availableVirtualCores),
        health_report: .healthReport
      }
  ] | sort_by(.node_host_name)')"

observed_hosts="$(printf '%s' "${observed_nodes}" | jq -r 'map(.node_host_name) | join(",")')"
[[ "${observed_hosts}" == "nodemanager-1,nodemanager-2" ]] || {
  echo "Expected NodeManager hosts nodemanager-1,nodemanager-2, observed ${observed_hosts}; observed nodes: ${observed_nodes}" >&2
  exit 1
}

if ! printf '%s' "${observed_nodes}" | jq -e \
    'all(.[]; .state == "RUNNING" and .total_memory_mb == 2048 and .total_vcores == 2)' >/dev/null; then
  echo "Each NodeManager must advertise 2048 MB and 2 vcores; observed nodes: ${observed_nodes}" >&2
  exit 1
fi

computed_total_memory="$(printf '%s' "${observed_nodes}" | jq '[.[].total_memory_mb] | add')"
computed_total_vcores="$(printf '%s' "${observed_nodes}" | jq '[.[].total_vcores] | add')"
[[ "${computed_total_memory}" -eq 4096 ]] || {
  echo "Expected 4096 MB computed from per-node YARN evidence, observed ${computed_total_memory}; observed nodes: ${observed_nodes}" >&2
  exit 1
}
[[ "${computed_total_vcores}" -eq 4 ]] || {
  echo "Expected 4 vcores computed from per-node YARN evidence, observed ${computed_total_vcores}; observed nodes: ${observed_nodes}" >&2
  exit 1
}

metrics_json=""
last_metrics_state="not attempted"
metrics_ready=false
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  if metrics_json="$(curl --fail --silent --show-error \
      --connect-timeout "${curl_connect_timeout_seconds}" \
      --max-time "${curl_max_time_seconds}" \
      "${rm_base_url}/metrics" 2>&1)"; then
    last_metrics_state="${metrics_json}"
    metrics_fields_present="$(printf '%s' "${metrics_json}" | jq -r '
      .clusterMetrics |
      has("totalMB") and (.totalMB | type) == "number" and
      has("totalVirtualCores") and (.totalVirtualCores | type) == "number"
    ' 2>/dev/null || printf 'false')"
    if [[ "${metrics_fields_present}" == "true" ]]; then
      total_memory="$(printf '%s' "${metrics_json}" | jq -r '.clusterMetrics.totalMB')"
      total_vcores="$(printf '%s' "${metrics_json}" | jq -r '.clusterMetrics.totalVirtualCores')"
      if [[ "${total_memory}" -eq "${computed_total_memory}" && "${total_vcores}" -eq "${computed_total_vcores}" ]]; then
        metrics_ready=true
        break
      fi
      last_metrics_state="totalMB=${total_memory}, totalVirtualCores=${total_vcores}, raw=${metrics_json}"
    else
      last_metrics_state="missing or mis-typed totalMB/totalVirtualCores: ${metrics_json}"
    fi
  else
    last_metrics_state="request failed: ${metrics_json:-no response}"
  fi
  if (( attempt < max_attempts )); then
    sleep "${poll_interval_seconds}"
  fi
done
if [[ "${metrics_ready}" != "true" ]]; then
  echo "YARN cluster metrics did not converge to ${computed_total_memory} MB/${computed_total_vcores} vcores after ${max_attempts} attempts; last observed state: ${last_metrics_state}" >&2
  exit 1
fi

get_yarn_conf() {
  local key="$1"
  local value
  if ! value="$(/opt/local-yarn/bin/read-hadoop-xml-property.sh "${yarn_site_path}" "${key}")"; then
    echo "Unable to inspect deployed YARN property ${key} in ${yarn_site_path}" >&2
    return 1
  fi
  printf '%s' "${value}"
}

minimum_memory_mb="$(get_yarn_conf yarn.scheduler.minimum-allocation-mb)"
maximum_memory_mb="$(get_yarn_conf yarn.scheduler.maximum-allocation-mb)"
minimum_vcores="$(get_yarn_conf yarn.scheduler.minimum-allocation-vcores)"
maximum_vcores="$(get_yarn_conf yarn.scheduler.maximum-allocation-vcores)"
scheduler_class="$(get_yarn_conf yarn.resourcemanager.scheduler.class)"

capacity_calculator="$(python3 -c '
import xml.etree.ElementTree as ET

target = "yarn.scheduler.capacity.resource-calculator"
root = ET.parse("/opt/hadoop/etc/hadoop/capacity-scheduler.xml").getroot()
matches = [
    (prop.findtext("value") or "").strip()
    for prop in root.findall("property")
    if (prop.findtext("name") or "").strip() == target
]
if len(matches) != 1 or not matches[0]:
    raise SystemExit(f"expected exactly one non-empty {target} property")
print(matches[0], end="")
')"

if ! scheduler_json="$(curl --fail --silent --show-error \
    --connect-timeout "${curl_connect_timeout_seconds}" \
    --max-time "${curl_max_time_seconds}" \
    "${rm_base_url}/scheduler" 2>&1)"; then
  echo "Unable to inspect the ResourceManager scheduler; last observed state: ${scheduler_json:-no response}" >&2
  exit 1
fi
if ! scheduler_rest_type="$(printf '%s' "${scheduler_json}" | jq -er '
    .scheduler.schedulerInfo.type | select(type == "string" and length > 0)
  ')"; then
  echo "YARN scheduler REST evidence omitted a non-empty scheduler type; observed scheduler: ${scheduler_json}" >&2
  exit 1
fi

[[ "${minimum_memory_mb}" == "256" ]] || { echo "Expected observed YARN minimum memory allocation 256 MB, observed ${minimum_memory_mb}" >&2; exit 1; }
[[ "${maximum_memory_mb}" == "2048" ]] || { echo "Expected observed YARN maximum memory allocation 2048 MB, observed ${maximum_memory_mb}" >&2; exit 1; }
[[ "${minimum_vcores}" == "1" ]] || { echo "Expected observed YARN minimum vcore allocation 1, observed ${minimum_vcores}" >&2; exit 1; }
[[ "${maximum_vcores}" == "2" ]] || { echo "Expected observed YARN maximum vcore allocation 2, observed ${maximum_vcores}" >&2; exit 1; }
[[ "${scheduler_class}" == "${expected_scheduler}" ]] || { echo "Expected CapacityScheduler class ${expected_scheduler}, observed ${scheduler_class}" >&2; exit 1; }
[[ "${capacity_calculator}" == "${expected_calculator}" ]] || { echo "Expected DominantResourceCalculator ${expected_calculator}, observed ${capacity_calculator}" >&2; exit 1; }
[[ "${scheduler_rest_type,,}" == "capacityscheduler" ]] || { echo "Expected CapacityScheduler from ResourceManager REST, observed ${scheduler_rest_type}; last observed scheduler state: ${scheduler_json}" >&2; exit 1; }

observed_policy="$(jq -c -n \
  --arg scheduler_class "${scheduler_class}" \
  --arg scheduler_rest_type "${scheduler_rest_type}" \
  --arg resource_calculator "${capacity_calculator}" \
  --argjson minimum_memory_mb "${minimum_memory_mb}" \
  --argjson maximum_memory_mb "${maximum_memory_mb}" \
  --argjson minimum_vcores "${minimum_vcores}" \
  --argjson maximum_vcores "${maximum_vcores}" \
  '{
    scheduler_class: $scheduler_class,
    scheduler_rest_type: $scheduler_rest_type,
    resource_calculator: $resource_calculator,
    minimum_memory_mb: $minimum_memory_mb,
    maximum_memory_mb: $maximum_memory_mb,
    minimum_vcores: $minimum_vcores,
    maximum_vcores: $maximum_vcores
  }')"

echo "OBSERVED_NODEMANAGER_RESOURCES=${observed_nodes}"
echo "OBSERVED_YARN_RESOURCE_POLICY=${observed_policy}"
printf '%s\n' "${nodes_json}" | jq .
printf '%s\n' "${metrics_json}" | jq .
printf '%s\n' "${scheduler_json}" | jq .
echo "YARN_VERIFICATION=PASS"
