#!/bin/bash

set -e -x

docker run -t --rm -v `pwd`:/build quay.io/pypa/manylinux1_x86_64 /build/scripts/build-manylinux.sh

docker run -t --rm -v `pwd`:/build quay.io/pypa/manylinux1_i686 linux32 /build/scripts/build-manylinux.sh

