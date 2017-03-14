FROM debian:jessie

ENV SPLUNK_PRODUCT splunk
ENV SPLUNK_VERSION 6.4.6
ENV SPLUNK_BUILD 6635aa31e851
ENV SPLUNK_FILENAME splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-Linux-x86_64.tgz

ENV SPLUNK_HOME_TCP /opt/splunk_tcp
ENV SPLUNK_HOME_SSL /opt/splunk_ssl

ENV SPLUNK_GROUP splunk
ENV SPLUNK_USER splunk

ARG DEBIAN_FRONTEND=noninteractive

# add splunk:splunk user
RUN groupadd -r ${SPLUNK_GROUP} \
    && useradd -r -m -g ${SPLUNK_GROUP} ${SPLUNK_USER}

# make the "en_US.UTF-8" locale so splunk will be utf-8 enabled by default
RUN apt-get update && apt-get install -y locales \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# pdfgen dependency
RUN apt-get install -y libgssapi-krb5-2

# Download official Splunk release, verify checksum and unzip in /opt/splunk_{tcp,ssl}
RUN apt-get install -y wget sudo \
    && mkdir -p ${SPLUNK_HOME_TCP} \
    && mkdir -p ${SPLUNK_HOME_SSL} \
    && wget -qO /tmp/${SPLUNK_FILENAME} https://download.splunk.com/products/${SPLUNK_PRODUCT}/releases/${SPLUNK_VERSION}/linux/${SPLUNK_FILENAME} \
    && wget -qO /tmp/${SPLUNK_FILENAME}.md5 https://download.splunk.com/products/${SPLUNK_PRODUCT}/releases/${SPLUNK_VERSION}/linux/${SPLUNK_FILENAME}.md5 \
    && (cd /tmp && md5sum -c ${SPLUNK_FILENAME}.md5) \
    && tar xzf /tmp/${SPLUNK_FILENAME} --strip 1 -C ${SPLUNK_HOME_TCP} \
    && tar xzf /tmp/${SPLUNK_FILENAME} --strip 1 -C ${SPLUNK_HOME_SSL} \
    && rm /tmp/${SPLUNK_FILENAME} \
    && rm /tmp/${SPLUNK_FILENAME}.md5 \
    && apt-get purge -y --auto-remove wget \
    && chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME_TCP} \
    && chown -R ${SPLUNK_USER}:${SPLUNK_GROUP} ${SPLUNK_HOME_SSL} \
    && rm -rf /var/lib/apt/lists/*

##### Copy config files #####
### TCP
## TCP raw
# etc/apps/search/local/{inputs,props}.conf
## HEC
# etc_tcp/apps/splunk_httpinput/local/inputs.conf
## system config
# etc/system/local/server.conf

### SSL
## TCP raw
# etc/apps/search/local/{inputs,props}.conf
## HEC
# etc/apps/splunk_httpinput/local/inputs.conf
## Certificates
# etc/auth/server.pem
# etc/auth/cacert.pem
## system config
# etc/system/local/server.conf
# etc/system/local/web.conf

COPY etc_tcp/apps/splunk_httpinput/local/inputs.conf ${SPLUNK_HOME_TCP}/etc/apps/splunk_httpinput/local/inputs.conf
COPY etc_ssl/apps/splunk_httpinput/local/inputs.conf ${SPLUNK_HOME_SSL}/etc/apps/splunk_httpinput/local/inputs.conf

COPY etc_tcp/apps/search/local/inputs.conf ${SPLUNK_HOME_TCP}/etc/apps/search/local/inputs.conf
COPY etc_tcp/apps/search/local/props.conf ${SPLUNK_HOME_TCP}/etc/apps/search/local/props.conf
COPY etc_ssl/apps/search/local/inputs.conf ${SPLUNK_HOME_SSL}/etc/apps/search/local/inputs.conf
COPY etc_ssl/apps/search/local/props.conf ${SPLUNK_HOME_SSL}/etc/apps/search/local/props.conf

COPY etc_ssl/auth/server.pem ${SPLUNK_HOME_SSL}/etc/auth/server.pem
COPY etc_ssl/auth/cacert.pem ${SPLUNK_HOME_SSL}/etc/auth/cacert.pem

COPY etc_tcp/system/local/server.conf ${SPLUNK_HOME_TCP}/etc/system/local/server.conf
COPY etc_ssl/system/local/server.conf ${SPLUNK_HOME_SSL}/etc/system/local/server.conf
COPY etc_ssl/system/local/web.conf ${SPLUNK_HOME_SSL}/etc/system/local/web.conf

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh

# Ports Splunk Web, Splunk Daemon, KVStore, Splunk Indexing Port, Network Input, HTTP Event Collector
#EXPOSE 8000/tcp 8089/tcp 8191/tcp 12300/tcp 1514 8088/tcp
#EXPOSE 8200/tcp 8289/tcp 8391/tcp 11250/tcp 1714 8288/tcp

WORKDIR /opt

ENTRYPOINT ["/sbin/entrypoint.sh"]
