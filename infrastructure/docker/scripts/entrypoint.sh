#!/usr/bin/env bash
set -euo pipefail

role="${1:-spark-client}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "${role}" in
  namenode)
    if [[ ! -f /data/dfs/name/current/VERSION ]]; then
      echo "Formatting empty LOCAL_YARN_V1 NameNode volume"
      hdfs namenode -format -nonInteractive -clusterId LOCAL-YARN-V1
    fi
    exec hdfs namenode
    ;;
  datanode)
    exec hdfs datanode
    ;;
  resourcemanager)
    exec yarn resourcemanager
    ;;
  nodemanager)
    : "${NM_HOSTNAME:?NM_HOSTNAME is required for a NodeManager}"
    exec yarn nodemanager
    ;;
  hdfs-init)
    exec /opt/local-yarn/bin/init-hdfs.sh
    ;;
  history-server)
    exec spark-class org.apache.spark.deploy.history.HistoryServer
    ;;
  spark-client)
    exec sleep infinity
    ;;
  verify-services)
    exec /opt/local-yarn/bin/verify-services.sh "$@"
    ;;
  verify-hdfs)
    exec /opt/local-yarn/bin/verify-hdfs.sh "$@"
    ;;
  verify-yarn)
    exec /opt/local-yarn/bin/verify-yarn.sh "$@"
    ;;
  verify-spark)
    exec /opt/local-yarn/bin/verify-spark.sh "$@"
    ;;
  verify-correlation)
    exec /opt/local-yarn/bin/verify-correlation.sh "$@"
    ;;
  version-report)
    exec /opt/local-yarn/bin/snapshot-container.sh "$@"
    ;;
  snapshot-yarn-config)
    exec /opt/local-yarn/bin/snapshot-yarn-config.sh "$@"
    ;;
  *)
    exec "${role}" "$@"
    ;;
esac
