#!/bin/bash
set -e

# Create the test database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE hideaway_sports_book_test_db;
    GRANT ALL PRIVILEGES ON DATABASE hideaway_sports_book_test_db TO $POSTGRES_USER;
EOSQL

echo "Test database created successfully!"
