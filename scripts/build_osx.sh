#!/bin/bash

# Create OSX wheels for psycopg2
#
# Following instructions from https://github.com/MacPython/wiki/wiki/Spinning-wheels
# Cargoculting pieces of implementation from https://github.com/matthew-brett/multibuild

set -euo pipefail
set -x

# 2.6.6 not available for 10.6
# 3.2.5 3.3.5 fail with:

#   Package /Volumes/Python/Python.mpkg/Contents/Packages/PythonFramework-3.2.pkg
#   uses a deprecated pre-10.2 format (or uses a newer format but is invalid).
#   installer: The install failed (The Installer could not install the software
#   because there was no software found to install.)

PYVERSIONS="2.7.15 3.4.4 3.5.4 3.6.6 3.7.0"

brew update > /dev/null
brew install gnu-sed

brew uninstall postgresql postgis
brew tap petere/postgresql
brew install postgresql@10
pip install virtualenv

export PATH=/usr/local/opt/postgresql@10/bin:$PATH

# Find psycopg version
VERSION=$(grep -e ^PSYCOPG_VERSION psycopg2/setup.py | gsed "s/.*'\(.*\)'/\1/")
DISTDIR="psycopg2/dist/psycopg2-$VERSION"
mkdir -p "$DISTDIR"

build_wheels () {
    PYVER3=$1

    # Python version number in different formats
    PYVER2=${PYVER3:0:3}
    VERNUM=$(( $(echo $PYVER2 | gsed 's/\(.\+\)\.\(.\+\)/100 * \1 + \2/') ))

    # Install the selected Python version
    if (( "$VERNUM" >= 300 )); then
        PKGEXT=$(if (( "$VERNUM" >= 304 )); then echo "pkg"; else echo "dmg"; fi)
    else
        PKGEXT=$(if (( "$VERNUM" >= 207 )); then echo "pkg"; else echo "dmg"; fi)
    fi

    PYINST="python-${PYVER3}-macosx10.6.${PKGEXT}"
    wget --quiet "https://www.python.org/ftp/python/${PYVER3}/$PYINST"

    if [ "$PKGEXT" == "dmg" ]; then
        hdiutil attach $PYINST -mountpoint /Volumes/Python
        PYINST=/Volumes/Python/Python.mpkg
    fi

    sudo installer -pkg "$PYINST" -target /

    # Install certificates for Python 3.6
    CERT_CMD="/Applications/Python ${PYVER2}/Install Certificates.command"
    if [ -e "$CERT_CMD" ]; then
        sh "$CERT_CMD"
    fi

    # Work with the selected python
    PYPREFIX=/Library/Frameworks/Python.framework/Versions
    PYEXE=${PYPREFIX}/${PYVER2}/bin/python${PYVER2}
    ENVDIR="env-${PYVER2}"
    virtualenv -p "$PYEXE" "$ENVDIR"
    set +u
    source "${ENVDIR}/bin/activate"
    set -u

    # Install pip without pip because now pip has a problem pipping pip
    # https://github.com/geerlingguy/mac-dev-playbook/issues/61
    wget --quiet -O - https://bootstrap.pypa.io/get-pip.py | python
    pip install -U wheel delocate

    # Replace the package name
    if [[ "${PACKAGE_NAME:-}" ]]; then
        gsed -i "s/^setup(name=\"psycopg2\"/setup(name=\"${PACKAGE_NAME}\"/" \
            ./psycopg2/setup.py
    fi

    # Insert a warning to deprecate the wheel version of the base package
    if [[ -z "${PACKAGE_NAME:-}" ]]; then
        grep -q warnings ./psycopg2/lib/__init__.py ||
            cat >> ./psycopg2/lib/__init__.py << 'EOF'


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

    # Build the wheels
    WHEELDIR="${ENVDIR}/wheels"
    pip wheel -w ${WHEELDIR} ./psycopg2/
    delocate-listdeps ${WHEELDIR}/*.whl

    # Check where is the libpq. I'm gonna kill it for testing
    if [[ -z "${LIBPQ:-}" ]]; then
        export LIBPQ=$(delocate-listdeps ${WHEELDIR}/*.whl | grep libpq)
    fi

    delocate-wheel ${WHEELDIR}/*.whl
    # https://github.com/MacPython/wiki/wiki/Spinning-wheels#question-will-pip-give-me-a-broken-wheel
    delocate-addplat --rm-orig -x 10_9 -x 10_10 ${WHEELDIR}/*.whl
    cp ${WHEELDIR}/*.whl ${DISTDIR}

    # Reset python to whatever
    set +u
    deactivate
    set -u
}

test_wheels () {
    PYVER3=$1

    PYVER2=${PYVER3:0:3}

    # Work with the selected python
    PYPREFIX=/Library/Frameworks/Python.framework/Versions
    PYEXE=${PYPREFIX}/${PYVER2}/bin/python${PYVER2}
    ENVDIR="test-${PYVER2}"
    virtualenv -p "$PYEXE" "$ENVDIR"
    source "${ENVDIR}/bin/activate"

    # Install and test the built wheel
    export PSYCOPG2_TESTDB_USER=postgres
    export PSYCOPG2_TESTDB_FAST=1
    pip install ${PACKAGE_NAME:-psycopg2} --no-index -f "$DISTDIR"

    # Print psycopg and libpq versions
    python -c "import psycopg2; print(psycopg2.__version__)"
    python -c "import psycopg2; print(psycopg2.__libpq_version__)"
    python -c "import psycopg2; print(psycopg2.extensions.libpq_version())"

    # fail if we are not using the expected libpq library
    # Disabled as we just use what's available on the system on OSX
    # if [[ "${WANT_LIBPQ:-}" ]]; then
    #     python -c "import psycopg2, sys; sys.exit(${WANT_LIBPQ} != psycopg2.extensions.libpq_version())"
    # fi

    python -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"

    # Reset python to whatever
    deactivate
}

# Build wheels for the supported python versions
for i in $PYVERSIONS; do
    build_wheels $i
done

# now we have a postgres 9.6 running (from the .travis.yml file) but postgres
# 10 has overridden the symlink used as lib directory by the running server:
# this will make some tests fail. So get rid of the newer postgres and restore
# the symlink.

brew uninstall postgresql
brew install postgresql@9.6
ln -s $(/usr/local/Cellar/postgresql@9.6/*/bin/pg_config --libdir) /usr/local/lib/postgresql

for i in $PYVERSIONS; do
    test_wheels $i
done
