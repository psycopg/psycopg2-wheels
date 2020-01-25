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

# Build libpq if needed
# This recipe is very similar to that in build_libpq.sh, for
# Linux. Consider keeping them in sync.
if [ ! -d "postgres-${POSTGRES_TAG}/" ]; then
    curl -sL \
        https://github.com/postgres/postgres/archive/${POSTGRES_TAG}.tar.gz \
        | tar xzf -

    cd "postgres-${POSTGRES_TAG}/"

    brew rm --force postgresql postgis

    ./configure --prefix=/usr/local --without-readline \
        --with-gssapi --with-openssl --with-ldap \
        --disable-debug
    (cd src/interfaces/libpq && make)
    (cd src/bin/pg_config && make)
    # This will fail after installing postgres_fe.h, which is what we need
    (cd src/include && make)
else
    cd "postgres-${POSTGRES_TAG}/"
fi

# Install libpq
(cd src/interfaces/libpq && make install)
(cd src/bin/pg_config && make install)
# This will fail after installing postgres_fe.h, which is what we need
(cd src/include && make install || true)
cd ..
