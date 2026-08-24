#!/usr/bin/env bash
set -euo pipefail

case "${1:-namenode}" in
  namenode)
    curl --fail --silent --show-error --connect-timeout 2 --max-time 4 \
      'http://localhost:9870/jmx?qry=Hadoop:service=NameNode,name=NameNodeStatus' \
      | jq -e '.beans[0].State == "active"' >/dev/null
    ;;
  datanode)
    curl --fail --silent --show-error --connect-timeout 2 --max-time 4 \
      'http://localhost:9864/jmx?qry=Hadoop:service=DataNode,name=DataNodeInfo' \
      | jq -e '.beans | length > 0' >/dev/null
    ;;
  *)
    echo "Unknown HDFS healthcheck role: $1" >&2
    exit 2
    ;;
esac
