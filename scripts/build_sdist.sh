#!/bin/bash

set -e -x

cd $TRAVIS_BUILD_DIR/psycopg2

# Find psycopg version
export VERSION=$(grep -e ^PSYCOPG_VERSION setup.py | sed "s/.*'\(.*\)'/\1/")

# Build the source package
python setup.py sdist -d "dist/psycopg2-$VERSION"

# install and test
sudo pip install "dist/psycopg2-$VERSION"/*

export PSYCOPG2_TESTDB_USER=postgres
export PSYCOPG2_TEST_FAST=1
python -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
