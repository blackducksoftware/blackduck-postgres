#!/bin/sh

# Using Unix socket connection to test readiness.
pg_isready --username=blackduck --dbname=bds_hub --port=5432 --quiet
status=$?

if [ "$status" == "0" ];
then
  # PostgreSQL is accepting connections.
  exit 0
fi

if [ "$status" == "1" ];
then
  echo "PostgreSQL is still starting up."
  exit 0
fi

if [ "$status" == "2" ];
then
	echo "PostgreSQL is not responding."
	exit 1
fi

if [ "$status" == "3" ];
then
	echo "pg_isready failed."
	exit 1
fi

# Should not get here
exit 1
