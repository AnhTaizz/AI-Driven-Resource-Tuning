#!/usr/bin/env bash

export JAVA_HOME=/opt/java/openjdk
export HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop
export YARN_CONF_DIR=/opt/hadoop/etc/hadoop
export PYSPARK_PYTHON=/opt/python/bin/python3.10
export PYSPARK_DRIVER_PYTHON=/opt/python/bin/python3.10
export LD_LIBRARY_PATH="/opt/python/lib:${LD_LIBRARY_PATH:-}"
export SPARK_DIST_CLASSPATH
SPARK_DIST_CLASSPATH="$(/opt/hadoop/bin/hadoop classpath)"
export SPARK_DAEMON_MEMORY=384m
export SPARK_HISTORY_OPTS="-Dspark.history.ui.port=18080"
