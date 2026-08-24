#!/usr/bin/env bash
set -euo pipefail

readonly config_path="${1:?Hadoop XML configuration path is required}"
readonly property_name="${2:?Hadoop property name is required}"
readonly command_timeout_seconds="${HADOOP_XML_PROPERTY_TIMEOUT_SECONDS:-10}"

timeout --signal=TERM "${command_timeout_seconds}s" \
  python3 - "${config_path}" "${property_name}" <<'PY'
import sys
import xml.etree.ElementTree as ET

config_path, property_name = sys.argv[1:3]
matches = []
for prop in ET.parse(config_path).getroot().findall("property"):
    name = (prop.findtext("name") or "").strip()
    if name == property_name:
        matches.append((prop.findtext("value") or "").strip())

if len(matches) != 1:
    raise SystemExit(
        f"expected exactly one {property_name!r} property in {config_path}, "
        f"observed {len(matches)}"
    )
if not matches[0]:
    raise SystemExit(f"property {property_name!r} is empty in {config_path}")

print(matches[0], end="")
PY
