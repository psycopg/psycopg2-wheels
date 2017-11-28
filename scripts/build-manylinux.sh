#!/bin/bash

# Create manylinux1 wheels for psycopg2
#
# Run this script with something like:
#
# docker run --rm -v `pwd`:/build quay.io/pypa/manylinux1_x86_64 /build/scripts/build-manylinux.sh
# docker run --rm -v `pwd`:/build quay.io/pypa/manylinux1_i686 linux32 /build/scripts/build-manylinux.sh
#
# Tests run against a postgres on the host. Use -e PSYCOPG_TESTDB_USER=... etc
# to configure tests run.

set -e -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create prerequisite libraries
libdir="$DIR/../libs/$(uname -p)/"
mkdir -p "$libdir"
cd "$libdir"

${DIR}/build_libpq.sh > /dev/null

# Find psycopg version
export VERSION=$(grep -e ^PSYCOPG_VERSION /build/psycopg2/setup.py | sed "s/.*'\(.*\)'/\1/")
export DISTDIR="/build/psycopg2/dist/psycopg2-$VERSION"

# Create the wheel packages
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" wheel /build/psycopg2/ -w /build/psycopg2/wheels/
done

# Patch auditwheel to avoid including libresolv
POLICY=/opt/_internal/cpython-3.6.0/lib/python3.6/site-packages/auditwheel/policy/policy.json
grep -q libresolv $POLICY || patch $POLICY << 'EOF'
diff --git a/auditwheel/policy/policy.json b/auditwheel/policy/policy.json
index ed37aaf..fe13834 100644
--- a/auditwheel/policy/policy.json
+++ b/auditwheel/policy/policy.json
@@ -24,6 +24,6 @@
          "libc.so.6", "libnsl.so.1", "libutil.so.1", "libpthread.so.0",
          "libX11.so.6", "libXext.so.6", "libXrender.so.1", "libICE.so.6",
          "libSM.so.6", "libGL.so.1", "libgobject-2.0.so.0",
-         "libgthread-2.0.so.0", "libglib-2.0.so.0"
+         "libgthread-2.0.so.0", "libglib-2.0.so.0", "libresolv.so.2"
      ]}
 ]
EOF

# Bundle external shared libraries into the wheels
for WHL in /build/psycopg2/wheels/*.whl; do
    auditwheel repair "$WHL" -w "$DISTDIR"
done

# Make sure libpq is not in the system
rm /usr/local/lib/libpq.*

# Connect to the host to test. Use 'docker -e' to pass other variables
export PSYCOPG2_TESTDB_HOST=$(ip route show | awk '/default/ {print $3}')

# Install packages and test
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" install psycopg2 --no-index -f "$DISTDIR"

    # Print psycopg and libpq versions
    "${PYBIN}/python" -c "import psycopg2; print(psycopg2.__version__)"
    "${PYBIN}/python" -c "import psycopg2; print(psycopg2.__libpq_version__)"
    "${PYBIN}/python" -c "import psycopg2; print(psycopg2.extensions.libpq_version())"

    # fail if we are not using the expected libpq library
    if [[ -n "$WANT_LIBPQ" ]]; then
        "${PYBIN}/python" -c "import psycopg2, sys; sys.exit(${WANT_LIBPQ} != psycopg2.extensions.libpq_version())"
    fi

    "${PYBIN}/python" -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
done
