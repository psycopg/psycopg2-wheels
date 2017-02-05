#!/bin/bash

# Download and build a postgres package
# The PGVER env variable should be set to the patch-level version to work on
# (e.g. '7.4.10')

set -e -x

export PACKAGE=${PACKAGE:-$(echo "$PGVER" | sed 's/\([0-9]\+\.[0-9]\+\).*/\1/')}
export URL=${URL:-https://ftp.postgresql.org/pub/source/v${PGVER}/postgresql-${PGVER}.tar.bz2}

wget -O - "$URL" | tar xjf -

cd "postgresql-$PGVER"
./configure --prefix "/opt/postgresql-${PACKAGE}"
make
sudo make install

# Create a tar package of the built system
# Use this directory to allow uploading it away
DISTDIR="${TRAVIS_BUILD_DIR}/psycopg2/dist/"
mkdir -p "$DISTDIR"
tar cjf "${DISTDIR}/postgresql-${PACKAGE}.tar.bz2" -c /opt "/opt/postgresql-${PACKAGE}"
