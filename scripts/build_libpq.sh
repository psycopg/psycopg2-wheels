#!/bin/bash

# Build a modern version of libpq and depending libs from source on Centos 5

set -e -x
set -o pipefail

OPENSSL_VERSION="1.0.2q"
LDAP_VERSION="2.4.44"
# If you change this, fix WANT_LIBPQ too in .travis.yml
POSTGRES_VERSION="11.1"

OPENSSL_TAG="OpenSSL_${OPENSSL_VERSION//./_}"
LDAP_TAG="${LDAP_VERSION}"
POSTGRES_TAG="REL_${POSTGRES_VERSION//./_}"

yum install -y zlib-devel krb5-devel pam-devel cyrus-sasl-devel

# Build openssl if needed
if [ ! -d "openssl-${OPENSSL_TAG}/" ]; then
    curl -sL \
        https://github.com/openssl/openssl/archive/${OPENSSL_TAG}.tar.gz \
        | tar xzf -

    cd "openssl-${OPENSSL_TAG}/"

    # Expose the lib version number in the .so file name
    sed -i "s/SHLIB_VERSION_NUMBER\s\+\".*\""\
"/SHLIB_VERSION_NUMBER \"${OPENSSL_VERSION}\"/" \
        ./crypto/opensslv.h
    sed -i "s|if (\$shlib_version_number =~ /(^\[0-9\]\*)\\\.(\[0-9\\\.\]\*)/)"\
"|if (\$shlib_version_number =~ /(^[0-9]*)\.([0-9\.]*[a-z]?)/)|" \
        ./Configure

    ./config --prefix=/usr/local/ --openssldir=/usr/local/ \
        zlib -fPIC shared --with-krb5-flavor=MIT
    make depend
    make

    # Check the shlib built has the correct version number in the name
    if [[ ! -f "./libssl.so.${OPENSSL_VERSION}" ]]; then
        echo >&2 "libssl.so.${OPENSSL_VERSION} not found, there is $(ls libssl.so.*)"
        exit 1
    fi
else
    cd "openssl-${OPENSSL_TAG}/"
fi

# Install openssl
make install
cd ..

# Build openldap if needed
if [ ! -d "openldap-${LDAP_TAG}/" ]; then
    curl -sL \
        https://www.openldap.org/software/download/OpenLDAP/openldap-release/openldap-${LDAP_TAG}.tgz \
        | tar xzf -

    cd "openldap-${LDAP_TAG}/"

    ./configure --enable-backends=no --enable-null
    make depend
    (cd libraries/liblutil/ && make)
    (cd libraries/liblber/ && make)
    (cd libraries/libldap/ && make)
    (cd libraries/libldap_r/ && make)
else
    cd "openldap-${LDAP_TAG}/"
fi

# Install openldap
(cd libraries/liblber/ && make install)
(cd libraries/libldap/ && make install)
(cd libraries/libldap_r/ && make install)
(cd include/ && make install)
chmod +x /usr/local/lib/{libldap,liblber}*.so*
cd ..

# Build libpq if needed
if [ ! -d "postgres-${POSTGRES_TAG}/" ]; then
    curl -sL \
        https://github.com/postgres/postgres/archive/${POSTGRES_TAG}.tar.gz \
        | tar xzf -

    cd "postgres-${POSTGRES_TAG}/"

    # Match the default unix socket dir default with what defined on Ubuntu and
    # Red Hat, which seems the most common location
    sed -i 's|#define DEFAULT_PGSOCKET_DIR .*'\
'|#define DEFAULT_PGSOCKET_DIR "/var/run/postgresql"|' \
        src/include/pg_config_manual.h

    ./configure --prefix=/usr/local --without-readline \
        --with-gssapi --with-openssl --with-pam --with-ldap
    (cd src/interfaces/libpq && make)
    (cd src/bin/pg_config && make)
    # This will fail after installing postgres_fe.h, which is what we need
    (cd src/include && make)
else
    cd "postgres-${POSTGRES_TAG}/"
fi

# Install libpq
(cd src/interfaces/libpq && make install)
(cd src/bin/pg_config && make install)
# This will fail after installing postgres_fe.h, which is what we need
(cd src/include && make install || true)
cd ..

find /usr/local/ -name \*.so.\* -type f -exec strip --strip-unneeded {} \;
