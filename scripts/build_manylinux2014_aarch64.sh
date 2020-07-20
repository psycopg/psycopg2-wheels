#!/bin/bash

set -euo pipefail
# set -x

docker run --rm -v $TRAVIS_BUILD_DIR:/build \
    -e PSYCOPG2_TESTDB_USER=postgres -e PSYCOPG2_TEST_FAST=1 \
    -e WANT_LIBPQ -e PACKAGE_NAME \
    quay.io/pypa/manylinux2014_aarch64 /build/scripts/build-manylinux.sh
