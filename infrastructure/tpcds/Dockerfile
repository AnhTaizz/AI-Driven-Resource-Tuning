# syntax=docker/dockerfile:1
FROM --platform=linux/amd64 docker.io/library/debian:bookworm-slim@sha256:5ae3c39ebd15e229dcedd5cee596b2497182493d41ff162e824ba13fc1b2b867

ARG GCC_VERSION=4:12.2.0-3
ARG GCC_12_VERSION=12.2.0-14+deb12u1
ARG LIBGCC_12_DEV_VERSION=12.2.0-14+deb12u1
ARG LIBC6_DEV_VERSION=2.36-9+deb12u14
ARG MAKE_VERSION=4.3-4.1
ARG FLEX_VERSION=2.6.4-8.2
ARG BISON_VERSION=2:3.8.2+dfsg-1+b1
ARG BINUTILS_VERSION=2.40-2
ARG FILE_VERSION=1:5.44-3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gcc=${GCC_VERSION} \
        gcc-12=${GCC_12_VERSION} \
        libgcc-12-dev=${LIBGCC_12_DEV_VERSION} \
        libc6-dev=${LIBC6_DEV_VERSION} \
        make=${MAKE_VERSION} \
        flex=${FLEX_VERSION} \
        bison=${BISON_VERSION} \
        binutils=${BINUTILS_VERSION} \
        file=${FILE_VERSION} \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C \
    LC_ALL=C \
    TZ=UTC

COPY build-toolkit.sh /usr/local/bin/tpcds-build-toolkit
RUN chmod 0555 /usr/local/bin/tpcds-build-toolkit

LABEL ai.resource-tuning.component="tpcds-toolkit-builder" \
      ai.resource-tuning.contract="P04B" \
      ai.resource-tuning.platform="linux/amd64"

WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/tpcds-build-toolkit"]
