#!/usr/bin/env bash
set -euo pipefail

readonly yarn_site_path="/opt/hadoop/etc/hadoop/yarn-site.xml"
readonly capacity_scheduler_path="/opt/hadoop/etc/hadoop/capacity-scheduler.xml"

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

capacity_config="$(python3 -c '
import json
import xml.etree.ElementTree as ET

path = "/opt/hadoop/etc/hadoop/capacity-scheduler.xml"
properties = {}
duplicates = []
for prop in ET.parse(path).getroot().findall("property"):
    name = (prop.findtext("name") or "").strip()
    value = (prop.findtext("value") or "").strip()
    if name:
        if name in properties:
            duplicates.append(name)
        properties[name] = value

if duplicates:
    raise SystemExit("duplicate deployed capacity-scheduler properties: " + ",".join(sorted(set(duplicates))))

required = {
    "resource_calculator": "yarn.scheduler.capacity.resource-calculator",
    "root_queues": "yarn.scheduler.capacity.root.queues",
    "default_capacity_percent": "yarn.scheduler.capacity.root.default.capacity",
    "default_maximum_capacity_percent": "yarn.scheduler.capacity.root.default.maximum-capacity",
    "default_state": "yarn.scheduler.capacity.root.default.state",
    "default_submit_acl": "yarn.scheduler.capacity.root.default.acl_submit_applications",
    "default_admin_acl": "yarn.scheduler.capacity.root.default.acl_administer_queue",
    "default_maximum_am_resource_percent": "yarn.scheduler.capacity.root.default.maximum-am-resource-percent",
    "default_user_limit_factor": "yarn.scheduler.capacity.root.default.user-limit-factor",
}
missing = [source for source in required.values() if source not in properties]
if missing:
    raise SystemExit("missing deployed capacity-scheduler properties: " + ",".join(missing))

result = {target: properties[source] for target, source in required.items()}
result["root_queues"] = [part.strip() for part in result["root_queues"].split(",") if part.strip()]
result["default_capacity_percent"] = float(result["default_capacity_percent"])
result["default_maximum_capacity_percent"] = float(result["default_maximum_capacity_percent"])
result["default_maximum_am_resource_percent"] = float(result["default_maximum_am_resource_percent"])
result["default_user_limit_factor"] = float(result["default_user_limit_factor"])
print(json.dumps(result, separators=(",", ":")), end="")
')"

jq -c -n \
  --arg observation_kind "OBSERVED_DEPLOYED_CONFIG" \
  --arg observed_at_utc "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg yarn_site_source "${yarn_site_path}" \
  --arg capacity_scheduler_source "${capacity_scheduler_path}" \
  --arg scheduler_class "${scheduler_class}" \
  --argjson minimum_memory_mb "${minimum_memory_mb}" \
  --argjson maximum_memory_mb "${maximum_memory_mb}" \
  --argjson minimum_vcores "${minimum_vcores}" \
  --argjson maximum_vcores "${maximum_vcores}" \
  --argjson capacity "${capacity_config}" \
  '{
    observation_kind: $observation_kind,
    observed_at_utc: $observed_at_utc,
    sources: {
      yarn_site: $yarn_site_source,
      capacity_scheduler: $capacity_scheduler_source
    },
    scheduler_class: $scheduler_class,
    minimum_allocation: {
      memory_mb: $minimum_memory_mb,
      vcores: $minimum_vcores
    },
    maximum_allocation: {
      memory_mb: $maximum_memory_mb,
      vcores: $maximum_vcores
    },
    capacity_scheduler: $capacity
  }'
