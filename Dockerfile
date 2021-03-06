FROM java:8-jre
MAINTAINER Kevin Kuhl <kevin@wayblazer.com>

ENV DEBIAN_FRONTEND noninteractive

# required tools
RUN apt-get update -y && apt-get install -y --no-install-recommends \
  wget \
  curl \
  vim \
  net-tools #Needed for ifconfig

# install neo4j
RUN wget -O - http://debian.neo4j.org/neotechnology.gpg.key | apt-key add - && \
    echo 'deb http://debian.neo4j.org/repo testing/' > /etc/apt/sources.list.d/neo4j.list
RUN apt-get update -y && apt-get install -y --no-install-recommends \
  neo4j-enterprise=3.0.0.M05 \
  supervisor

# cleanup
RUN apt-get autoremove -y wget curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# configure
ADD start.sh /start.sh
ADD neo4j.conf /etc/neo4j/neo4j.conf
ADD neo4j-wrapper.conf /etc/neo4j/neo4j-wrapper.conf
ADD server_supervisord.conf /etc/supervisor/conf.d/server.conf

#Stage these for when $ES_HOST is used
ADD plugins/* /tmp/neo4j/plugins/

RUN touch /tmp/rrd

#Mount data and logs
VOLUME ["/data", "/logs"]

ENV REMOTE_HTTP=true \
    REMOTE_SHELL=true \
    ARBITER=false \
    INIT_MEMORY=1024 \
    MAX_MEMORY=3072 \
    MODE=SINGLE

EXPOSE 7474
CMD ["/start.sh"]
