#!/bin/bash

set -e -x

# Print sha1 checksum in portable format. You can copy the output of this
# command and paste it into `shasum -c` to verify packages downloaded locally.
(cd psycopg2/dist && shasum -p -a 1 */*)

rsync -avr \
    -e "ssh -i /tmp/id_rsa-initd-upload -o 'UserKnownHostsFile known_hosts' -o 'StrictHostKeyChecking yes'" \
    psycopg2/dist/ "upload@initd.org:"
