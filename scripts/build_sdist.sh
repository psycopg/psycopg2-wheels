#!/bin/bash

# Find psycopg version
export VERSION=$(grep -e ^PSYCOPG_VERSION /psycopg2/setup.py | sed "s/.*'\(.*\)'/\1/")

# Build the source package
cd $TRAVIS_BUILD_DIR/psycopg2
python setup.py sdist -d "dist/psycopg2-$VERSION"

# install and test
pip install "dist/psycopg2-$VERSION"/*

export PSYCOPG2_TESTDB_USER=postgres
export PSYCOPG2_TEST_FAST=1
python -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
