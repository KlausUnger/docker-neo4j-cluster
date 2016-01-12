FROM ubuntu:trusty
MAINTAINER Kevin Kuhl <kevin@wayblazer.com>
ENV DEBIAN_FRONTEND noninteractive

# required tools
RUN apt-get update
RUN apt-get install -y wget curl

# install neo4j
RUN wget -O - http://debian.neo4j.org/neotechnology.gpg.key | apt-key add -
RUN echo 'deb http://debian.neo4j.org/repo stable/' > /etc/apt/sources.list.d/neo4j.list
RUN apt-get update -y
RUN apt-get install -y neo4j-enterprise=2.3.1 neo4j-arbiter=2.3.1 supervisor

# cleanup
RUN apt-get autoremove -y wget
RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/*

# configure
ADD start.sh /start.sh
ADD arbiter_supervisord.conf /etc/supervisor/conf.d/arbiter.conf
ADD server_supervisord.conf /etc/supervisor/conf.d/server.conf
ADD neo4j.properties /etc/neo4j/neo4j.properties
ADD neo4j-server.properties /etc/neo4j/neo4j-server.properties
ADD neo4j-wrapper.conf /etc/neo4j/neo4j-wrapper.conf

#Stage these for when $ES_HOST is used
ADD plugins/* /tmp/neo4j/plugins/

RUN touch /tmp/rrd

#Mount data and logs
VOLUME ["/data", "/logs"]

ENV REMOTE_HTTP true
ENV REMOTE_SHELL true
ENV ARBITER false
ENV INIT_MEMORY 512
ENV MAX_MEMORY 10000

EXPOSE 5001
EXPOSE 6001
EXPOSE 7474
EXPOSE 6362

CMD ["/start.sh"]
