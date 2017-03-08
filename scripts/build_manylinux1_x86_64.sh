#!/bin/bash

docker run --rm -v $TRAVIS_BUILD_DIR:/build \
    -e PSYCOPG2_TESTDB_USER=postgres -e PSYCOPG2_TEST_FAST=1 \
    quay.io/pypa/manylinux1_x86_64 /build/scripts/build-manylinux.sh
