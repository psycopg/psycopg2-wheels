#!/bin/bash

# Open a reverse tunnel to a server to allow connecting into this machine
#!
set -euxo pipefail

# Try to get a shell into Travis
cat disclaimer.txt

# Allow connecting to the ssh server
cat id_rsa-psycopg-upload.pub >> ~/.ssh/authorized_keys

# Set up private key required for connection
openssl aes-256-cbc \
    -K $encrypted_bd656d6a5753_key -iv $encrypted_bd656d6a5753_iv \
    -in data/id_rsa-psycopg-upload.enc -out data/id_rsa-psycopg-upload -d

chmod 600 data/{known_hosts,id_rsa-psycopg-upload}

# Keep writing on stdout to avoid being disconnected after 10 mins
while true; do echo "now is $(date)"; sleep 60; done &

# Open a tunnel where I can pick it up
ssh -i data/id_rsa-psycopg-upload -N -v \
    -o 'UserKnownHostsFile data/known_hosts' \
    -o 'StrictHostKeyChecking yes' \
    -o 'ExitOnForwardFailure yes' \
    -R 2223:localhost:22 piro@upload.psycopg.org

# Note: the receiving end should be configured with:
#
# no-pty,command="/bin/false" ssh-rsa AAAAB3...(public key) id_rsa_upload
#
# On the receiving side you want to run something like:
# ssh -i .ssh/id_rsa_upload -p 2223 travis@localhost
