#!/bin/sh

# Using Unix socket connection to test readiness.
pg_isready --username=blackduck --dbname=bds_hub --port=5432 --quiet
queryResult=$?

if [ "$queryResult" == "0" ];
then
  # PostgreSQL is accepting connections.
  exit 0
fi

if [ "$queryResult" == "1" ];
then
  # PostgreSQL is still starting up.
  exit 0
fi

# PostgreSQL is not responding.
exit 1

