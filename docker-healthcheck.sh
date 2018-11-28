#!/bin/sh

# Using Unix socket connection to test readiness.
queryResult="$(psql --username=blackduck --dbname=bds_hub --port=5432 --tuples-only --no-align --quiet -c 'SELECT 1')"
if [ "$queryResult" == "1" ];
then
  # Successful PostgreSQL Unix socket connection and query result.
  exit 0
fi

# Unsuccessful PostgreSQL Unix socket connection or query result.
exit 1

