#!/bin/bash

set -euo pipefail
# set -x

if [ -z "${encrypted_bd656d6a5753_key:-}" ]; then
    echo "encrypted key missing: skipping upload" >&2
    exit 0
fi

# Set up files required for upload
openssl aes-256-cbc \
    -K $encrypted_bd656d6a5753_key -iv $encrypted_bd656d6a5753_iv \
    -in data/id_rsa-psycopg-upload.enc -out data/id_rsa-psycopg-upload -d

chmod 600 data/{known_hosts,id_rsa-psycopg-upload,ssh_config}

# Print sha1 checksum in portable format. You can copy the output of this
# command and paste it into `shasum -c` to verify packages downloaded locally.
(cd psycopg2/dist && shasum -p -a 1 */*)

rsync -avr -e "ssh -F data/ssh_config" psycopg2/dist/ upload:
