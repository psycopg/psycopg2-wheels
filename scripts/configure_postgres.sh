# Configure postgres to receive connection from dockers

set -e -x

if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
    CONFIG_DIR=/etc/postgresql/9.6/main/

    # Listen on all the hosts
    sed -i "s/^\s*#\?\s*listen_addresses.*/listen_addresses = '*'/" \
      "$CONFIG_DIR/postgresql.conf"

    # Set messages to the level the test suite expects
    sed -i "s/^\s*#\?\s*client_min_messages.*/client_min_messages = notice/" \
      "$CONFIG_DIR/postgresql.conf"

    # Accept connection from everywhere to the test db
    echo "host psycopg2_test postgres 0.0.0.0/0 trust" \
      >> "$CONFIG_DIR/pg_hba.conf"

    service postgresql restart

else
    export PGDATA="`pwd`/data"
    initdb
    pg_ctl -w -l /dev/null start
    psql -c 'create user postgres superuser' postgres
fi

# Create the database for the test suite
psql -c 'create database psycopg2_test' -U postgres
