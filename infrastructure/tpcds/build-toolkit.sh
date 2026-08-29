#!/bin/sh
set -eu

print_metadata() {
    printf 'OS_ID=%s\n' "$(. /etc/os-release && printf '%s' "$ID")"
    printf 'OS_VERSION_ID=%s\n' "$(. /etc/os-release && printf '%s' "$VERSION_ID")"
    printf 'ARCHITECTURE=%s\n' "$(uname -m)"
    printf 'LIBC_IDENTITY=%s\n' "$(ldd --version 2>&1 | sed -n '1p')"
    printf 'COMPILER_VERSION=%s\n' "$(gcc --version | sed -n '1p')"
    printf 'MAKE_VERSION=%s\n' "$(make --version | sed -n '1p')"
    printf 'FLEX_VERSION=%s\n' "$(flex --version | sed -n '1p')"
    printf 'BISON_VERSION=%s\n' "$(bison --version | sed -n '1p')"
    printf 'BINUTILS_VERSION=%s\n' "$(readelf --version | sed -n '1p')"
    printf 'FILE_VERSION=%s\n' "$(file --version | sed -n '1p')"
    for package in gcc gcc-12 libgcc-12-dev libc6 libc6-dev make flex bison binutils file; do
        value=$(dpkg-query -W -f='${Version}' "$package")
        key=$(printf '%s' "$package" | tr '[:lower:]-' '[:upper:]_')
        printf 'PACKAGE_%s=%s\n' "$key" "$value"
    done
}

if [ "${1:-}" = "--metadata-only" ]; then
    print_metadata
    exit 0
fi

if [ "${1:-}" != "--build" ] || [ "$#" -ne 1 ]; then
    printf '%s\n' 'Only --metadata-only and --build are supported.' >&2
    exit 64
fi

: "${TPCDS_ARCHIVE_SHA256:?TPCDS_ARCHIVE_SHA256 is required}"
: "${TPCDS_ARCHIVE_SIZE_BYTES:?TPCDS_ARCHIVE_SIZE_BYTES is required}"
: "${TPCDS_SOURCE_ROOT:?TPCDS_SOURCE_ROOT is required}"

umask 022
test -f /input/archive.zip
test -d "/source/${TPCDS_SOURCE_ROOT}"
test -d /workspace
test ! -e /workspace/build-source
test ! -e /workspace/output
test ! -e /workspace/evidence

archive_size=$(stat -c '%s' /input/archive.zip)
archive_sha256=$(sha256sum /input/archive.zip | awk '{print $1}')
test "$archive_size" = "$TPCDS_ARCHIVE_SIZE_BYTES"
test "$archive_sha256" = "$TPCDS_ARCHIVE_SHA256"

mkdir -p /workspace/build-source /workspace/output/bin /workspace/output/share/tpcds /workspace/evidence
cp -a "/source/${TPCDS_SOURCE_ROOT}" /workspace/build-source/

print_metadata > /workspace/evidence/toolchain.txt
dpkg-query -W -f='${Package}\t${Version}\n' | LC_ALL=C sort > /workspace/evidence/dpkg-packages.txt
printf '%s\n' '["make","-f","makefile","OS=LINUX","CC=gcc","LEX=flex","YACC=bison -y","LINUX_CFLAGS=-g -Wall -fcommon","dsdgen","tpcds.idx"]' > /workspace/evidence/build-command.argv.json

cd "/workspace/build-source/${TPCDS_SOURCE_ROOT}/tools"
make -f makefile OS=LINUX CC=gcc LEX=flex "YACC=bison -y" "LINUX_CFLAGS=-g -Wall -fcommon" dsdgen tpcds.idx

for header in columns.h streams.h tables.h tpcds.idx.h; do
    test -s "$header"
done
test -x dsdgen
test -s tpcds.idx
test -x mkheader
test -x distcomp
test ! -e dsqgen
test ! -e checksum

cp dsdgen /workspace/output/bin/dsdgen
cp tpcds.idx /workspace/output/share/tpcds/tpcds.idx
chmod 0555 /workspace/output/bin/dsdgen
chmod 0444 /workspace/output/share/tpcds/tpcds.idx

file /workspace/output/bin/dsdgen > /workspace/evidence/dsdgen.file.txt
readelf -h /workspace/output/bin/dsdgen > /workspace/evidence/dsdgen.readelf.txt
sha256sum /workspace/output/bin/dsdgen /workspace/output/share/tpcds/tpcds.idx > /workspace/evidence/artifact-sha256.txt

if find /workspace -type f \( -iname '*.dat' -o -iname '*.parquet' -o -iname '*.snappy' \) -print -quit | grep -q .; then
    printf '%s\n' 'Forbidden dataset artifact found in P04B workspace.' >&2
    exit 65
fi
if find /workspace -type d \( -name TPCDS_DEBUG -o -name TPCDS_SF1 \) -print -quit | grep -q .; then
    printf '%s\n' 'Forbidden dataset directory found in P04B workspace.' >&2
    exit 66
fi

printf '%s\n' 'TPCDS_TOOLKIT_CONTAINER_BUILD=PASS'
