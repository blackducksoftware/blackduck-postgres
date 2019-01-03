# blackduck-postgres
Black Duck implementation of postgresql image for use with Black Duck application.

## Database Creation

Black Duck requires multiple databases within Postgres, which are created in one of two ways:

- The main application database, `bds_hub`, is created via the `POSTGRES_DB` environment variable and behavior defined in the base postgres container
- Additional databases are setup via SQL scripts such as `1-hub-setup.sql` and similar
