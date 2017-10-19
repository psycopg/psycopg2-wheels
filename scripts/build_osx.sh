#!/bin/bash

# Create OSX wheels for psycopg2
#
# Following instructions from https://github.com/MacPython/wiki/wiki/Spinning-wheels
# Cargoculting pieces of implementation from https://github.com/matthew-brett/multibuild

set -e -x

# 2.6.6 not available for 10.6
# 3.2.5 3.3.5 fail with:

#   Package /Volumes/Python/Python.mpkg/Contents/Packages/PythonFramework-3.2.pkg
#   uses a deprecated pre-10.2 format (or uses a newer format but is invalid).
#   installer: The install failed (The Installer could not install the software
#   because there was no software found to install.)

PYVERSIONS="2.7.13 3.4.4 3.5.3 3.6.0"

brew update
brew install gnu-sed

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
    wget "https://www.python.org/ftp/python/${PYVER3}/$PYINST"

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
    source "${ENVDIR}/bin/activate"
    pip install -U pip wheel delocate

    # Build the wheels
    WHEELDIR="${ENVDIR}/wheels"
    pip wheel -w ${WHEELDIR} ./psycopg2/
    delocate-listdeps ${WHEELDIR}/*.whl

    # Check where is the libpq. I'm gonna kill it for testing
    if [[ -z "$LIBPQ" ]]; then
        export LIBPQ=$(delocate-listdeps ${WHEELDIR}/*.whl | grep libpq)
    fi

    delocate-wheel ${WHEELDIR}/*.whl
    # https://github.com/MacPython/wiki/wiki/Spinning-wheels#question-will-pip-give-me-a-broken-wheel
    delocate-addplat --rm-orig -x 10_9 -x 10_10 ${WHEELDIR}/*.whl
    cp ${WHEELDIR}/*.whl ${DISTDIR}

    # Reset python to whatever
    deactivate
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
    pip install psycopg2 --no-index -f "$DISTDIR"
    python -c "from psycopg2 import tests; tests.unittest.main(defaultTest='tests.test_suite')"

    # Reset python to whatever
    deactivate
}

# Build wheels for the supported python versions
for i in $PYVERSIONS; do
    build_wheels $i
done

# kill the libpq to make sure tests don't depend on it
mv "$LIBPQ" "${LIBPQ}-bye"

for i in $PYVERSIONS; do
    test_wheels $i
done

# just because I'm a boy scout
mv "${LIBPQ}-bye" "$LIBPQ"

