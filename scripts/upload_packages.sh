#!/bin/bash

set -e

if [ "$encrypted_bd656d6a5753_key" == "" ]; then
    echo "encrypted key missing: skipping upload" >&2
    exit 0
fi

# Set up files required for upload
openssl aes-256-cbc \
    -K $encrypted_bd656d6a5753_key -iv $encrypted_bd656d6a5753_iv \
    -in id_rsa-travis-upload.enc -out /tmp/id_rsa-travis-upload -d

chmod 600 known_hosts /tmp/id_rsa-travis-upload

# Print sha1 checksum in portable format. You can copy the output of this
# command and paste it into `shasum -c` to verify packages downloaded locally.
(cd psycopg2/dist && shasum -p -a 1 */*)

rsync -avr \
    -e "ssh -i /tmp/id_rsa-travis-upload -o UserKnownHostsFile=known_hosts -o StrictHostKeyChecking=yes" \
    psycopg2/dist/ "psycopg@upload.psycopg.org:"
