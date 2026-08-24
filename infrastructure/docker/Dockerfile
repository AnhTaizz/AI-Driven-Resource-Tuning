ARG JAVA_BASE_IMAGE=eclipse-temurin:11.0.32_9-jdk-jammy
ARG JAVA_BASE_IMAGE_SOURCE=eclipse-temurin:11.0.32_9-jdk-jammy

FROM ${JAVA_BASE_IMAGE} AS builder

ARG HADOOP_VERSION=3.3.6
ARG HADOOP_SHA512=de3eaca2e0517e4b569a88b63c89fae19cb8ac6c01ff990f1ff8f0cc0f3128c8e8a23db01577ca562a0e0bb1b4a3889f8c74384e609cd55e537aada3dcaa9f8a
ARG SPARK_VERSION=3.5.9
ARG SPARK_SHA512=0ceafdcc46dff83272edbbe5a9a52c77e2c2c55672f67deaa33751e52e5e3ae13e3fc2c5deddec88d172a488cf8baa6c85cc0d2e88333217fdefccb303beda75
ARG PYTHON_VERSION=3.10.21
ARG PYTHON_SHA256=a0da1e72132e950154eca0f6f47d5db828454700de20e5113667940d81e0db04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        libbz2-dev \
        libffi-dev \
        liblzma-dev \
        libncursesw5-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        uuid-dev \
        xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/build

RUN curl --fail --location --retry 5 --retry-all-errors --connect-timeout 15 --max-time 1800 \
        --speed-limit 1024 --speed-time 120 --proto '=https' \
        --output "Python-${PYTHON_VERSION}.tar.xz" \
        "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz" \
    && echo "${PYTHON_SHA256}  Python-${PYTHON_VERSION}.tar.xz" | sha256sum --check --strict \
    && tar --extract --file "Python-${PYTHON_VERSION}.tar.xz" \
    && cd "Python-${PYTHON_VERSION}" \
    && ./configure \
        --prefix=/opt/python \
        --enable-shared \
        --with-ensurepip=install \
    && make -j2 \
    && make install \
    && LD_LIBRARY_PATH=/opt/python/lib /opt/python/bin/python3.10 --version

RUN curl --fail --location --retry 5 --retry-all-errors --connect-timeout 15 --max-time 1800 \
        --speed-limit 1024 --speed-time 120 --proto '=https' \
        --output "hadoop-${HADOOP_VERSION}.tar.gz" \
        "https://archive.apache.org/dist/hadoop/core/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" \
    && echo "${HADOOP_SHA512}  hadoop-${HADOOP_VERSION}.tar.gz" | sha512sum --check --strict \
    && tar --extract --file "hadoop-${HADOOP_VERSION}.tar.gz" --directory /opt \
    && mv "/opt/hadoop-${HADOOP_VERSION}" /opt/hadoop

RUN curl --fail --location --retry 5 --retry-all-errors --connect-timeout 15 --max-time 1800 \
        --speed-limit 1024 --speed-time 120 --proto '=https' \
        --output "spark-${SPARK_VERSION}-bin-without-hadoop.tgz" \
        "https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-without-hadoop.tgz" \
    && echo "${SPARK_SHA512}  spark-${SPARK_VERSION}-bin-without-hadoop.tgz" | sha512sum --check --strict \
    && tar --extract --file "spark-${SPARK_VERSION}-bin-without-hadoop.tgz" --directory /opt \
    && mv "/opt/spark-${SPARK_VERSION}-bin-without-hadoop" /opt/spark

COPY smoke/src/main/java/localyarn/LocalYarnSmoke.java /tmp/smoke-src/localyarn/LocalYarnSmoke.java
RUN mkdir -p /opt/local-yarn/smoke /tmp/smoke-classes \
    && javac -classpath '/opt/spark/jars/*' \
        -d /tmp/smoke-classes \
        /tmp/smoke-src/localyarn/LocalYarnSmoke.java \
    && jar --create \
        --file /opt/local-yarn/smoke/local-yarn-smoke.jar \
        --main-class localyarn.LocalYarnSmoke \
        -C /tmp/smoke-classes .

FROM ${JAVA_BASE_IMAGE}

ARG JAVA_BASE_IMAGE
ARG JAVA_BASE_IMAGE_SOURCE
ARG HADOOP_VERSION=3.3.6
ARG SPARK_VERSION=3.5.9
ARG PYTHON_VERSION=3.10.21

LABEL org.opencontainers.image.title="LOCAL_YARN_V1 Spark/Hadoop runtime" \
      org.opencontainers.image.description="Infrastructure-only local Spark-on-YARN research runtime" \
      org.opencontainers.image.version="spark-${SPARK_VERSION}-hadoop-${HADOOP_VERSION}-java11-python-${PYTHON_VERSION}" \
      local_yarn.java_base_image="${JAVA_BASE_IMAGE}" \
      local_yarn.java_base_image_source="${JAVA_BASE_IMAGE_SOURCE}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        libbz2-1.0 \
        libffi8 \
        liblzma5 \
        libncursesw6 \
        libreadline8 \
        libsqlite3-0 \
        libssl3 \
        libuuid1 \
        procps \
        unzip \
        zip \
        zlib1g \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 spark \
    && useradd --uid 10001 --gid spark --create-home --shell /bin/bash spark

COPY --from=builder /opt/python /opt/python
COPY --from=builder /opt/hadoop /opt/hadoop
COPY --from=builder /opt/spark /opt/spark
COPY --from=builder /opt/local-yarn/smoke /opt/local-yarn/smoke

ENV JAVA_HOME=/opt/java/openjdk \
    HADOOP_HOME=/opt/hadoop \
    HADOOP_COMMON_HOME=/opt/hadoop \
    HADOOP_HDFS_HOME=/opt/hadoop \
    HADOOP_MAPRED_HOME=/opt/hadoop \
    HADOOP_YARN_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    SPARK_HOME=/opt/spark \
    SPARK_CONF_DIR=/opt/spark/conf \
    PYTHON_HOME=/opt/python \
    PYSPARK_PYTHON=/opt/python/bin/python3.10 \
    PYSPARK_DRIVER_PYTHON=/opt/python/bin/python3.10 \
    LD_LIBRARY_PATH=/opt/python/lib \
    PATH=/opt/python/bin:/opt/spark/bin:/opt/spark/sbin:/opt/hadoop/bin:/opt/hadoop/sbin:/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TZ=Asia/Bangkok

COPY hadoop/ /opt/hadoop/etc/hadoop/
COPY spark/ /opt/spark/conf/
COPY scripts/ /opt/local-yarn/bin/

RUN ln -s /opt/python/bin/python3.10 /usr/local/bin/python3 \
    && ln -s /opt/python/bin/pip3.10 /usr/local/bin/pip3 \
    && printf '%s\n' '/opt/python/lib' > /etc/ld.so.conf.d/local-python.conf \
    && ldconfig \
    && mkdir -p \
        /data/dfs/name \
        /data/dfs/data \
        /data/hadoop/tmp \
        /data/yarn/local \
        /data/yarn/logs \
        /opt/local-yarn/evidence \
    && chmod +x /opt/local-yarn/bin/*.sh \
    && chown -R spark:spark \
        /data \
        /opt/hadoop \
        /opt/spark \
        /opt/python \
        /opt/local-yarn \
        /home/spark \
    && java -version \
    && python3 -c 'import bz2, lzma, sqlite3, ssl, sys, zlib; assert sys.version_info[:3] == (3, 10, 21)' \
    && hadoop version \
    && spark-submit --version

USER spark
WORKDIR /home/spark
ENTRYPOINT ["/opt/local-yarn/bin/entrypoint.sh"]
CMD ["spark-client"]
