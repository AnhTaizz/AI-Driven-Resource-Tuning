#!/usr/bin/env bash
set -euo pipefail

case "${1:-resourcemanager}" in
  resourcemanager)
    curl --fail --silent --show-error --connect-timeout 2 --max-time 4 \
      http://localhost:8088/ws/v1/cluster/info \
      | jq -e '.clusterInfo.state == "STARTED"' >/dev/null
    ;;
  nodemanager)
    curl --fail --silent --show-error --connect-timeout 2 --max-time 4 \
      http://localhost:8042/ws/v1/node/info \
      | jq -e '.nodeInfo.nodeHostName != null and .nodeInfo.nodeHealthy == true' >/dev/null
    ;;
  *)
    echo "Unknown YARN healthcheck role: $1" >&2
    exit 2
    ;;
esac
