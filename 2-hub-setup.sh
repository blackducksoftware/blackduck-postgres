#!/bin/sh
set -e

###
# Create multiple database(s) and set user permissions.
# (once PR#240 in docker-library is merged, and available, this could go away)
###

# bds_hub_report
# hub will connect to bds_hub_report as blackduck_user(non-administrative)
# users will connect to bds_hub_report as blackduck_reporter(read-only)
psql -c 'CREATE DATABASE bds_hub_report OWNER postgres ENCODING SQL_ASCII;'
psql -c 'CREATE USER blackduck_reporter;'
psql -U "$POSTGRES_USER" -d bds_hub_report << EOF
GRANT SELECT, INSERT, UPDATE, TRUNCATE, DELETE, REFERENCES ON ALL TABLES IN SCHEMA public TO blackduck_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public to blackduck_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, TRUNCATE, DELETE, REFERENCES ON TABLES TO blackduck_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO blackduck_user;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO blackduck_reporter;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO blackduck_reporter;
EOF

# Add Replication User
psql -c 'CREATE USER blackduck_replication REPLICATION CONNECTION LIMIT 5;'

# bdio
psql -c 'CREATE DATABASE bdio OWNER postgres ENCODING SQL_ASCII;'
psql -c 'GRANT ALL PRIVILEGES ON DATABASE bdio TO blackduck_user;'
psql -c 'ALTER DATABASE bdio SET standard_conforming_strings TO ON;'

###
# Host Based Authentication
# (needs to be kept in sync with hub-database.sh)
###
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

if [ -f /tmp/root.crt ];
then 
  mv /tmp/root.crt $PGDATA/root.crt
fi

if [ -f /tmp/hub-database.key ];
then 
  mv /tmp/hub-database.key $PGDATA/hub-database.key
fi

if [ -f /tmp/hub-database.crt ];
then
  mv /tmp/hub-database.crt $PGDATA/hub-database.crt 
fi
