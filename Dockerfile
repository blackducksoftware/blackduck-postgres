FROM blackducksoftware/hub-docker-common:1.0.4 as docker-common
FROM postgres:9.6.12-alpine

ARG VERSION
ARG LASTCOMMIT
ARG BUILDTIME
ARG BUILD

LABEL com.blackducksoftware.hub.vendor="Black Duck Software, Inc." \
      com.blackducksoftware.hub.version="$VERSION" \
      com.blackducksoftware.hub.lastCommit="$LASTCOMMIT" \
      com.blackducksoftware.hub.buildTime="$BUILDTIME" \
      com.blackducksoftware.hub.build="$BUILD" \
      com.blackducksoftware.hub.image="postgres"

ENV BLACKDUCK_RELEASE_INFO "com.blackducksoftware.hub.vendor=Black Duck Software, Inc. \
com.blackducksoftware.hub.version=$VERSION \
com.blackducksoftware.hub.lastCommit=$LASTCOMMIT \
com.blackducksoftware.hub.buildTime=$BUILDTIME \
com.blackducksoftware.hub.build=$BUILD"

RUN echo -e "$BLACKDUCK_RELEASE_INFO" > /etc/blackduckrelease

ENV POSTGRES_USER="postgres" \
    POSTGRES_DB="bds_hub" \
    POSTGRES_INITDB_ARGS="--no-locale" \
    BLACKDUCK_HOME="/opt/blackduck/hub"

RUN mkdir -p /opt/blackduck/hub/hub-database/bin 

COPY hub-database.sh config-settings.pgsql /
COPY 1-hub-setup.sql 2-hub-setup.sh docker-entrypoint-initdb.d/
COPY --from=docker-common certificate-manager.sh /opt/blackduck/hub/hub-database/bin/certmanager.sh
COPY docker-healthcheck.sh /usr/local/bin/docker-healthcheck.sh

RUN apk add --no-cache --virtual .hub-postgres-run-deps \
		curl \
		jq \
		openssl \
		tzdata \
    && chmod 755 /hub-database.sh \
    && chmod 775 $BLACKDUCK_HOME/hub-database/bin/certmanager.sh \
    && rm /usr/bin/nc

# Filebeat - Installation and Configuration #
ENV FILEBEAT_VERSION 5.2.2

RUN mkdir -p $BLACKDUCK_HOME/hub-filebeat \
	&& curl -L https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$FILEBEAT_VERSION-linux-x86_64.tar.gz | \
    tar xz --strip-components=1 -C $BLACKDUCK_HOME/hub-filebeat \
    && mkdir -p $BLACKDUCK_HOME/hub-filebeat/data \
	&& chown -R postgres:root $BLACKDUCK_HOME/hub-filebeat \
	&& chmod -R 775 $BLACKDUCK_HOME/hub-filebeat
	
COPY filebeat.yml $BLACKDUCK_HOME/hub-filebeat/filebeat.yml

ENTRYPOINT [ "/hub-database.sh" ] 
CMD [ "postgres" ]
