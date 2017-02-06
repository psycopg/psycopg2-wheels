#!/bin/bash

# Download and build a postgres package
# The PGVER env variable should be set to the patch-level version to work on
# (e.g. '7.4.10')

set -e -x

export PACKAGE=${PACKAGE:-$(echo "$PGVER" | sed 's/\([0-9]\+\.[0-9]\+\).*/\1/')}
export URL=${URL:-https://ftp.postgresql.org/pub/source/v${PGVER}/postgresql-${PGVER}.tar.gz}

# Download into a directory and try to work out what download
mkdir incoming
cd incoming
wget -O - "$URL" | tar xzf -
cd $(ls -t1 | head -1)

./configure --prefix "/usr/lib/postgresql/${PACKAGE}"
make
make -C contrib
sudo make install

# Create a tar package of the built system
# Use this directory to allow uploading it away
DISTDIR="${TRAVIS_BUILD_DIR}/psycopg2/dist/postgresql"
mkdir -p "$DISTDIR"
tar cjf "${DISTDIR}/postgresql-${PACKAGE}.tar.bz2" -C /usr/lib/postgresql "${PACKAGE}"
