#!/bin/bash

hubDatabaseDir=/opt/blackduck/hub/hub-database

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
echo "Updating pg_hba.conf"
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

dataPopulated=false

if [ -d "$PGDATA" ] && [ -s "$PGDATA/PG_VERSION" ];
then
	echo "Data directory populated"
	dataPopulated=true
else
	echo "Data directory not populated"
fi

## Server Certificate management
$hubDatabaseDir/bin/certmanager.sh db-server-cert --ca $targetCAHost:$targetCAPort --rootcert $PGDATA/root.crt --key $PGDATA/hub-database.key --cert $PGDATA/hub-database.crt --outputDirectory /tmp --commonName hub-database --san $targetDatabaseHost
exitCode=$?
if [ $exitCode -eq 0 ];
then
  # If cert not existed so cert newly created, set the ownership and copy over
  if [ -f /tmp/hub-database.key ] && [ -f /tmp/hub-database.crt ] && [ -f /tmp/root.crt ];
  then
  	echo "Configuring new server certificates"
  	
    chmod 644 /tmp/root.crt
    chmod 400 /tmp/hub-database.key
    chmod 644 /tmp/hub-database.crt

    # Check for presence of PGDATA directory.  If present, the database root certificate and
    # database server key and certificate can be copied if and only if the data directory
    # is already populated.  If the data directory is not yet populated, the database root
    # certificate and database server key and certificate cannot be copied as this prevents
    # proper PostgreSQL data directory initialization.
    if $dataPopulated;
    then
      # PGDATA directory exists and PG_VERSION exists and is greater than 0 bytes.
      # Copy files.  Otherwise, let initialization scripts handle copying.
      echo "Copying root certificate"
      mv /tmp/root.crt $PGDATA/root.crt

      echo "Copying database server private key"
      mv /tmp/hub-database.key $PGDATA/hub-database.key

      echo "Copying database server certificate"
      mv /tmp/hub-database.crt $PGDATA/hub-database.crt
    else
      echo "Data directory not yet populated - deferring to initialization script to setup server certificates"
    fi
  else
    # Cert existed/validated and so use existing
    echo "Valid database server certificate exists"
  fi
else
  echo "Unable to manage webapp database server certificate (Code: $exitCode)."
  exit $exitCode
fi

## Client Certificate management - Used to inter-database foreign data access
$hubDatabaseDir/bin/certmanager.sh db-client-cert --ca $targetCAHost:$targetCAPort --rootcert $PGDATA/root.crt --key $PGDATA/hub-db-user.key --cert $PGDATA/hub-db-user.crt --outputDirectory /tmp --commonName blackduck_user --autocopy false
exitCode=$?
if [ $exitCode -eq 0 ];
then

  # Convert naming to agnostic standard
  if [ -f /tmp/blackduck_user.crt ]
  then
  	echo "Renaming client certificate"
  	
  	# Convert client key to usable format
    mv /tmp/blackduck_user.crt /tmp/hub-db-user.crt
  fi
  
  if [ -f /tmp/blackduck_user.key ]
  then
  	echo "Renaming client key"
  	
  	# Convert client key to usable format
    mv /tmp/blackduck_user.key /tmp/hub-db-user.key
  fi
  
  if [ -f /tmp/blackduck_user.key.pkcs8 ]
  then
  	echo "Converting client key to RSA"
  	
  	# Convert client key to usable format
  	mv /tmp/blackduck_user.key.pkcs8 /tmp/hub-db-user.key.pkcs8
    
    openssl rsa -in /tmp/hub-db-user.key.pkcs8 -inform DER -modulus -out /tmp/hub-db-user-rsa.key
  fi
  
  # If cert not existed so cert newly created, set the ownership and copy over
  # Note that the db-client-cert command's behavior is significantly different from the db-server-sert command above - it moves and cleans up files very differently
  if [ -f /tmp/hub-db-user.key ] && [ -f /tmp/hub-db-user-rsa.key ] && [ -f /tmp/hub-db-user.crt ];
  then
  	echo "Configuring new client certificates"
  	
    chmod 400 /tmp/hub-db-user.key
    chmod 400 /tmp/hub-db-user-rsa.key
    chmod 644 /tmp/hub-db-user.crt

    # Check for presence of PGDATA directory.  If present, the database root certificate and
    # database client key and certificate can be copied if and only if the data directory
    # is already populated.  If the data directory is not yet populated, the database root
    # certificate and database client key and certificate cannot be copied as this prevents
    # proper PostgreSQL data directory initialization.
    if $dataPopulated;
    then
      # PGDATA directory exists and PG_VERSION exists and is greater than 0 bytes.
      # Copy files.  Otherwise, let initialization scripts handle copying.
      echo "Copying database client private key"
      mv /tmp/hub-db-user.key $PGDATA/hub-db-user.key
      
      echo "Copying database client private RSA key to $PGDATA/hub-db-user-rsa.key"
      mv /tmp/hub-db-user-rsa.key $PGDATA/hub-db-user-rsa.key

      echo "Copying database client certificate"
      mv /tmp/hub-db-user.crt $PGDATA/hub-db-user.crt
    else
      echo "Data directory not yet populated - deferring to initialization script to setup client certificates"
    fi
  else
    # Cert existed/validated and so use existing
    echo "Valid database client certificate exists"
  fi
else
  echo "Unable to manage webapp database client certificate (Code: $exitCode)."
  exit $exitCode
fi

# Apply postgres configuration changes that require a database restart to take affect.
# The initialization scripts take care of this the very first time the container is
# brought up. Otherwise, we need to start postgres, apply the changes, and stop postgres
# again.
configSettingsFile=/config-settings.pgsql
if $dataPopulated && [ -s ${configSettingsFile} ] ; then
	# Set the correct permissions on $PGDATA.  It seems that in some unidentified
	# circumstances, the PG container starts with $PGDATA world-readable, which causes
	# postgres to abort startup.  The container succeeds in starting up because
	# docker-entrypoint.sh sets the appropriate permissions on every startup, so let's
	# do that too.
	chmod 700 "$PGDATA" 2>/dev/null || :

	# internal start of server in order to allow set-up using psql-client
	# does not listen on external TCP/IP and waits until start finishes
	PGUSER="${PGUSER:-postgres}" \
	pg_ctl -D "$PGDATA" \
		-o "-c listen_addresses=''" \
		-w start

	echo "Applying configuration settings"
	psql -v ON_ERROR_STOP=1 -f ${configSettingsFile} postgres

	PGUSER="${PGUSER:-postgres}" \
	pg_ctl -D "$PGDATA" -m fast -w stop
fi

set -e

# Start Filebeat first
cd $BLACKDUCK_HOME/hub-filebeat
./filebeat start &
echo "Filebeat started successfully"

echo "Attempting to start Hub database."

exec /docker-entrypoint.sh "$@"
