#!/bin/bash

set -euo pipefail
# set -x

# Build libpq on macOS
# If you change this, fix WANT_LIBPQ too in .travis.yml
POSTGRES_VERSION="11.5"

POSTGRES_TAG="REL_${POSTGRES_VERSION//./_}"

# Force link to OpenSSL 1.1
export LDFLAGS="-L/usr/local/opt/openssl@1.1/lib ${LDFLAGS:-}"
export CPPFLAGS="-I/usr/local/opt/openssl@1.1/include ${CPPFLAGS:-}"

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

libdir="$dir/../libs/"
mkdir -p "$libdir"
cd "$libdir"

# Build libpq if needed
# This recipe is very similar to that in build_libpq.sh, for
# Linux. Consider keeping them in sync.
if [ ! -d "postgres-${POSTGRES_TAG}/" ]; then
    curl -sL \
        https://github.com/postgres/postgres/archive/${POSTGRES_TAG}.tar.gz \
        | tar xzf -

    cd "postgres-${POSTGRES_TAG}/"

    ./configure --prefix=/usr/local --without-readline \
        --with-gssapi --with-openssl --with-ldap \
        --disable-debug > /dev/null
    make -C src/interfaces/libpq > /dev/null
    make -C src/bin/pg_config > /dev/null
    make -C src/include > /dev/null
else
    cd "postgres-${POSTGRES_TAG}/"
fi

# Install libpq
make -C src/interfaces/libpq install > /dev/null
make -C src/bin/pg_config install > /dev/null
make -C src/include install > /dev/null
cd ..
