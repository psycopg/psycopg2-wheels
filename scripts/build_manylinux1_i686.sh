#!/bin/bash

docker run --rm -v $TRAVIS_BUILD_DIR/psycopg2:/psycopg2 \
    -e PSYCOPG2_TESTDB_USER=postgres -e PSYCOPG2_TEST_FAST=1 \
    quay.io/pypa/manylinux1_x86_64 /psycopg2/scripts/build-manylinux.sh
