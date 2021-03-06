CREATE EXTENSION pgcrypto;

CREATE USER blackduck WITH NOCREATEDB SUPERUSER NOREPLICATION BYPASSRLS;
CREATE SCHEMA st AUTHORIZATION blackduck;

CREATE USER blackduck_user NOCREATEDB NOSUPERUSER NOREPLICATION NOBYPASSRLS;
GRANT USAGE ON SCHEMA st TO blackduck_user;
GRANT SELECT, INSERT, UPDATE, TRUNCATE, DELETE, REFERENCES ON ALL TABLES IN SCHEMA st TO blackduck_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA st to blackduck_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA st GRANT SELECT, INSERT, UPDATE, TRUNCATE, DELETE, REFERENCES ON TABLES TO blackduck_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA st GRANT ALL PRIVILEGES ON SEQUENCES TO blackduck_user;

ALTER SYSTEM SET max_connections TO '300';
ALTER SYSTEM SET shared_buffers TO '1024MB';
ALTER SYSTEM SET temp_buffers TO '16MB';
ALTER SYSTEM SET work_mem TO '32MB';
ALTER SYSTEM SET maintenance_work_mem TO '32MB';
ALTER SYSTEM SET max_wal_size TO '8GB';
ALTER SYSTEM SET checkpoint_timeout TO '30min';
ALTER SYSTEM SET checkpoint_completion_target TO '0.8';
ALTER SYSTEM SET random_page_cost TO '4.0';
ALTER SYSTEM SET effective_cache_size TO '256MB';
ALTER SYSTEM SET default_statistics_target TO '100';
ALTER SYSTEM SET constraint_exclusion TO 'partition';
ALTER SYSTEM SET autovacuum TO 'on';
ALTER SYSTEM SET autovacuum_max_workers TO '20';
ALTER SYSTEM SET autovacuum_vacuum_cost_limit TO '2000';
ALTER SYSTEM SET autovacuum_vacuum_cost_delay TO '10ms';
ALTER SYSTEM SET max_locks_per_transaction TO '256';
ALTER SYSTEM SET escape_string_warning TO 'off';
ALTER SYSTEM SET standard_conforming_strings TO 'off';
ALTER SYSTEM SET ssl TO 'on';
ALTER SYSTEM SET ssl_cert_file TO 'hub-database.crt';
ALTER SYSTEM SET ssl_key_file TO 'hub-database.key';
ALTER SYSTEM SET ssl_ca_file TO 'root.crt';
ALTER SYSTEM SET log_destination TO 'stderr';
ALTER SYSTEM SET logging_collector TO 'on';
ALTER SYSTEM SET log_directory TO 'pg_log';
ALTER SYSTEM SET log_filename TO 'postgresql_%a.log';
ALTER SYSTEM SET log_truncate_on_rotation TO 'on';
ALTER SYSTEM SET log_rotation_age TO '1440';
ALTER SYSTEM SET log_line_prefix TO '%m %p ';
ALTER SYSTEM SET tcp_keepalives_idle TO '600';
ALTER SYSTEM SET tcp_keepalives_interval TO '30';
ALTER SYSTEM SET tcp_keepalives_count TO '10';
