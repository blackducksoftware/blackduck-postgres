# blackduck-postgres

Black Duck implementation of postgresql image for use with Black Duck application.

## Building

The docker container for this project can be built with the command

```
docker build --pull -t blackducksoftware/blackduck-postgres:${version} .
```

replacing `${version}` with the version you'd like to build locally

## Database Creation

Black Duck requires multiple databases within Postgres, which are created in one of two ways:

- The main application database, `bds_hub`, is created via the `POSTGRES_DB` environment variable and behavior defined in the base postgres container (specified within the `Dockerfile`)
- Additional databases are setup via SQL scripts such as `1-hub-setup.sql` and similar
