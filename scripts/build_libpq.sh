#!/bin/bash

# Build a modern version of libpq and depending libs from source on Centos 5

set -e -x

OPENSSL_VERSION="1.0.2k"
LDAP_VERSION="2.4.44"
POSTGRES_VERSION="9.6.2"

OPENSSL_TAG="OpenSSL_${OPENSSL_VERSION//./_}"
LDAP_TAG="${LDAP_VERSION}"
POSTGRES_TAG="REL${POSTGRES_VERSION//./_}"

yum install -y zlib-devel krb5-devel pam-devel cyrus-sasl-devel

wget -q -O - https://github.com/openssl/openssl/archive/${OPENSSL_TAG}.tar.gz \
	| tar xzf -
cd "openssl-${OPENSSL_TAG}/"

# Expose the lib version number in the .so file name
# It doesn't really work: the final letter is not exposed.
# You can use strings /path/to/libssl.so | grep '^OpenSSL ' to get the version
# sed -i "s/SHLIB_VERSION_NUMBER\s\+\".*\"/SHLIB_VERSION_NUMBER \"${OPENSSL_VERSION}\"/" \
#     ./crypto/opensslv.h

./config --prefix=/usr/local/ --openssldir=/usr/local/ \
    zlib -fPIC shared --with-krb5-flavor=MIT
make depend
make && make install
cd ..

wget -q -O - \
    ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-${LDAP_TAG}.tgz \
	| tar xzf -
cd "openldap-${LDAP_TAG}/"
./configure --enable-backends=no --enable-null
make depend
(cd libraries/liblutil/ && make)
(cd libraries/liblber/ && make && make install)
(cd libraries/libldap/ && make && make install)
(cd libraries/libldap_r/ && make && make install)
(cd include/ && make install)
chmod +x /usr/local/lib/{libldap,liblber}*.so*
cd ..

wget -q -O - https://github.com/postgres/postgres/archive/${POSTGRES_TAG}.tar.gz \
	| tar xzf -

cd "postgres-${POSTGRES_TAG}/"

# Match the default unix socket dir default with what defined on Ubuntu and
# Red Hat, which seems the most common location
sed -i 's|#define DEFAULT_PGSOCKET_DIR .*'\
'|#define DEFAULT_PGSOCKET_DIR "/var/run/postgresql"|' \
	src/include/pg_config_manual.h

./configure --prefix=/usr/local --without-readline \
	--with-gssapi --with-openssl --with-pam --with-ldap
(cd src/interfaces/libpq && make && make install)
(cd src/bin/pg_config && make && make install)
# This will fail after installing postgres_fe.h, which is what we need
(cd src/include && make && make install || true)
cd ..
