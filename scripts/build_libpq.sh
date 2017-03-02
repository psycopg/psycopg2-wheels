#!/bin/bash

# Build a modern version of libpq from source on Centos 5

# work in progress, to be tested entirely

set -e -x

yum install -y zlib-devel krb5-devel pam-devel openldap-devel

wget -O - https://github.com/openssl/openssl/archive/OpenSSL_1_0_2k.tar.gz | tar xzvf -
cd openssl-OpenSSL_1_0_2k/

./config --prefix=/usr/local/ --openssldir=/usr/local/ zlib no-idea no-mdc2 no-rc5 no-ec no-ecdh no-ecdsa shared --with-krb5-flavor=MIT 
make depend
make
make install
cd ..

wget -O - https://github.com/postgres/postgres/archive/REL9_6_2.tar.gz | tar xzvf -

cd postgres-REL9_6_2/
./configure --without-readline --with-gssapi --with-openssl --with-pam --with-ldap --prefix=/usr/local

cd src/interfaces/libpq
make
make install
cd ../../../

cd src/bin/pg_config
make
make install
cd ../../../

cd src/include
make
# This will fail after installing postgres_fe.h, which is what we need
make install || true
