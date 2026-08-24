#!/usr/bin/env bash
set -euo pipefail

curl --fail --silent --show-error --connect-timeout 2 --max-time 4 \
  http://localhost:18080/api/v1/version \
  | jq -e '.spark != null' >/dev/null
