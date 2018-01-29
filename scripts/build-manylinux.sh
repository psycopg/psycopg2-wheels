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

set -euo pipefail
set -x

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create prerequisite libraries
libdir="$DIR/../libs/$(uname -p)/"
mkdir -p "$libdir"
cd "$libdir"

${DIR}/build_libpq.sh > /dev/null

# Find psycopg version
export VERSION=$(grep -e ^PSYCOPG_VERSION /build/psycopg2/setup.py | sed "s/.*'\(.*\)'/\1/")
export DISTDIR="/build/psycopg2/dist/psycopg2-$VERSION"

# Replace the package name
if [[ "${PACKAGE_NAME:-}" ]]; then
    sed -i "s/^setup(name=\"psycopg2\"/setup(name=\"${PACKAGE_NAME}\"/" \
        /build/psycopg2/setup.py
fi

# Insert a warning to deprecate the wheel version of the base package
if [[ -z "${PACKAGE_NAME:-}" ]]; then
    grep -q warnings /build/psycopg2/lib/__init__.py ||
        cat >> /build/psycopg2/lib/__init__.py << 'EOF'


# This is a wheel package: issue a warning on import
from warnings import warn   # noqa
warn("""\
The psycopg2 wheel package will be renamed from release 2.8; in order to \
keep installing from binary please use "pip install psycopg2-binary" instead. \
For details see: \
<http://initd.org/psycopg/docs/install.html#binary-install-from-pypi>.\
""")
EOF
fi

# Create the wheel packages
for PYBIN in /opt/python/*/bin; do
    if $(${PYBIN}/python --version 2>&1  | grep -qE '2\.6|3\.2|3\.3'); then
        "${PYBIN}/pip" install "wheel<0.30"
    fi
    "${PYBIN}/pip" wheel /build/psycopg2/ -w /build/psycopg2/wheels/
done

# Make sure auditwheel will not include libresolv
POLICY=/opt/_internal/cpython-3.6.*/lib/python3.6/site-packages/auditwheel/policy/policy.json
grep -q libresolv $POLICY

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
    "${PYBIN}/pip" install ${PACKAGE_NAME:-psycopg2} --no-index -f "$DISTDIR"

    # Print psycopg and libpq versions
    "${PYBIN}/python" -c "import psycopg2; print(psycopg2.__version__)"
    "${PYBIN}/python" -c "import psycopg2; print(psycopg2.__libpq_version__)"
    "${PYBIN}/python" -c "import psycopg2; print(psycopg2.extensions.libpq_version())"

    # fail if we are not using the expected libpq library
    if [[ "${WANT_LIBPQ:-}" ]]; then
        "${PYBIN}/python" -c "import psycopg2, sys; sys.exit(${WANT_LIBPQ} != psycopg2.extensions.libpq_version())"
    fi

    "${PYBIN}/python" -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"
done
