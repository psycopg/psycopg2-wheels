#!/bin/bash

# Create macOS wheels for psycopg2
#
# Following instructions from https://github.com/MacPython/wiki/wiki/Spinning-wheels
# Cargoculting pieces of implementation from https://github.com/matthew-brett/multibuild

set -euo pipefail
set -x

PYVERSIONS="2.7.15 3.5.4 3.6.6 3.7.0 3.8.0"

brew update > /dev/null
brew install gnu-sed

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create prerequisite libraries
libdir="$DIR/../libs/"
mkdir -p "$libdir"
(cd "$libdir" && bash ${DIR}/build_libpq_macos.sh > /dev/null)

# Update pip without needing pip or you will hit problems
# because pip 9.0.1 is ancient and TLSV1_ALERT_PROTOCOL_VERSION.
which pip
pip --version
virtualenv --version || true
wget --quiet -O - https://bootstrap.pypa.io/get-pip.py | sudo python3
pip install virtualenv
which pip
pip --version
virtualenv --version

# Find psycopg version
VERSION=$(grep -e ^PSYCOPG_VERSION psycopg2/setup.py | gsed "s/.*'\(.*\)'/\1/")
# A gratuitous comment to fix broken vim syntax file: '")
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

    if (( "$VERNUM" >= 308 )); then
        OSXVER=10.9
    else
        OSXVER=10.6
    fi

    PYINST="python-${PYVER3}-macosx${OSXVER}.${PKGEXT}"
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
    gsed -i "s/^setup(name=\"psycopg2\"/setup(name=\"${PACKAGE_NAME}\"/" \
        ./psycopg2/setup.py

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
    pip install ${PACKAGE_NAME} --no-index -f "$DISTDIR"

    # Print psycopg and libpq versions
    python -c "import psycopg2; print(psycopg2.__version__)"
    python -c "import psycopg2; print(psycopg2.__libpq_version__)"
    python -c "import psycopg2; print(psycopg2.extensions.libpq_version())"

    # fail if we are not using the expected libpq library
    # Disabled as we just use what's available on the system on macOS
    # if [[ "${WANT_LIBPQ:-}" ]]; then
    #     python -c "import psycopg2, sys; sys.exit(${WANT_LIBPQ} != psycopg2.extensions.libpq_version())"
    # fi

    cd ./psycopg2
    python -c "import tests; tests.unittest.main(defaultTest='tests.test_suite')"
    cd ..

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
