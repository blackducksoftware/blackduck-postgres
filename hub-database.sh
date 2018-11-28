#!/bin/bash

hubDatabaseDir=/opt/blackduck/hub/hub-database

# Print out preconditions : Especially important for various selinux / openshift scenarios.
function preconditions {
  echo "Debug info: Attempting to start database in $hubDatabaseDir."
  echo "Debug info: Contents of database directory: `ls -altrh $hubDatabaseDir`."
  echo "Debug info: Running as `whoami` : detailed info = `id`".
  echo "Debug info: Pgdata contents: `ls -altrh $PGDATA`."
  echo "Debug info: My user ID is `whoami | id -u`."
  echo "Debug info: The postgres user ID is `id -u postgres`."
}

preconditions

if [ ! -f "$hubDatabaseDir/bin/certmanager.sh" ];
then
  echo "ERROR: Cert manager shell script is not present."
  exit 1
fi

targetCAHost="${HUB_CFSSL_HOST:-cfssl}"
targetCAPort="${HUB_CFSSL_PORT:-8888}"
targetDatabaseHost="${HUB_POSTGRES_HOST:-postgres}"

echo "Certificate authority host: $targetCAHost"
echo "Certificate authority port: $targetCAPort"
echo "Database host: $targetDatabaseHost"

## Until we need another requirement from customers that they need to make a change on pg_hba.conf
## trigger this each time when starting a container.
## (needs to be kept in sync with 2-hub-setup.sh)
if [ -d "$PGDATA" ] && [ -s "$PGDATA/PG_VERSION" ];
then
cat <<- EOF > $PGDATA/pg_hba.conf
# TYPE    DATABASE          USER                  ADDRESS                 METHOD
local     all             	all                   						  trust
hostssl   bds_hub  			blackduck             0.0.0.0/0                 cert clientcert=1
hostssl   bds_hub           blackduck_user        0.0.0.0/0                 cert clientcert=1
hostssl   bds_hub_report    blackduck             0.0.0.0/0                 cert clientcert=1
hostssl   bds_hub_report    blackduck_user        0.0.0.0/0                 cert clientcert=1
hostnossl bds_hub_report    blackduck_reporter    0.0.0.0/0          	    md5
hostssl   bdio              blackduck             0.0.0.0/0                 cert clientcert=1
hostssl   bdio              blackduck_user        0.0.0.0/0                 cert clientcert=1
hostnossl replication       blackduck_replication 0.0.0.0/0          	    md5
hostnossl all             	all                   0.0.0.0/0                 reject
EOF
fi

## Certificate management
$hubDatabaseDir/bin/certmanager.sh db-server-cert --ca $targetCAHost:$targetCAPort --rootcert $PGDATA/root.crt --key $PGDATA/hub-database.key --cert $PGDATA/hub-database.crt --outputDirectory /tmp --commonName hub-database --san $targetDatabaseHost
exitCode=$?
if [ $exitCode -eq 0 ];
then
  # If cert not existed so cert newly created, set the ownership and copy over
  if [ -f /tmp/hub-database.key ] && [ -f /tmp/hub-database.crt ] && [ -f /tmp/root.crt ];
  then
    chmod 644 /tmp/root.crt
    chmod 400 /tmp/hub-database.key
    chmod 644 /tmp/hub-database.crt

    # Check for presence of PGDATA directory.  If present, the database root certificate and
    # database server key and certificate can be copied if and only if the data directory
    # is already populated.  If the data directory is not yet populated, the database root
    # certificate and database server key and certificate cannot be copied as this prevents
    # proper PostgreSQL data directory initialization.
    if [ -d "$PGDATA" ] && [ -s "$PGDATA/PG_VERSION" ];
    then
      # PGDATA directory exists and PG_VERSION exists and is greater than 0 bytes.
      # Copy files.  Otherwise, let initialization scripts handle copying.
      echo "Copying root certificate to $PGDATA/root.crt"
      mv /tmp/root.crt $PGDATA/root.crt

      echo "Copying database server private key to $PGDATA/hub-database.key"
      mv /tmp/hub-database.key $PGDATA/hub-database.key

      echo "Copying database server certificate to $PGDATA/hub-database.crt"
      mv /tmp/hub-database.crt $PGDATA/hub-database.crt
    fi
  else
    # Cert existed/validated and so use existing
    echo "Valid database server certificate exists"
  fi
else
  echo "Unable to manage webapp database server certificate (Code: $exitCode)."
  exit $exitCode
fi

set -e

# Start Filebeat first
cd $BLACKDUCK_HOME/hub-filebeat
./filebeat start &
echo "Filebeat started successfully"

echo "Attempting to start Hub database."

exec /docker-entrypoint.sh "$@"
