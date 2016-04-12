#!/bin/bash

echo ""
echo " __      __               __________.__                              ";
echo "/  \    /  \_____  ___.__.\______   \  | _____  ________ ___________ ";
echo "\   \/\/   /\__  \<   |  | |    |  _/  | \__  \ \___   // __ \_  __ \\";
echo " \        /  / __ \\\\___  | |    |   \  |__/ __ \_/    /\  ___/|  | \/";
echo "  \__/\  /  (____  / ____| |______  /____(____  /_____ \\\\___  >__|   ";
echo "       \/        \/\/             \/          \/      \/    \/       ";
echo ""
#set -x

#Handler for SIGTERM/INT from `docker stop` or Ctl+C
_term() {
  echo "Kill signal received, stopping supervisor."
  kill -TERM "$PID" 2>/dev/null
}

trap _term TERM INT

#If this has already been started, just start it don't process the configs.
if [ -f /tmp/.lock ]; then
  echo "Container has already been initialized. Starting supervisord."
  if [ "$ARBITER" = "true" ]; then
    echo "==> Starting Neo4J Arbiter (with supervisord)"
    echo
    supervisord -c /etc/supervisor/conf.d/arbiter.conf &
    PID=$!
    wait $PID
    exit 0;
  else
    echo "==> Starting Neo4J Server (with supervisord)"
    echo
    supervisord -c /etc/supervisor/conf.d/server.conf &
    PID=$!
    wait $PID
    exit 0;
  fi
fi

# Customize config
echo "==> Setting server IP config"
CONFIG_FILE=/etc/neo4j/neo4j.conf
WRAPPER_CONFIG=/etc/neo4j/neo4j-wrapper.conf
SERVER_CONFIG=/etc/neo4j/neo4j-server.properties
JMX_ACCESS_FILE=/etc/neo4j/jmx.access
JMX_PASSWORD_FILE=/etc/neo4j/jmx.password

#Set up memory bounds for Neo4j
sed -i '/wrapper.java.maxmemory/s/^#//' $WRAPPER_CONFIG
sed -i "/^wrapper.java.maxmemory/s/MAX_MEMORY/$MAX_MEMORY/" $WRAPPER_CONFIG

sed -i '/wrapper.java.initmemory/s/^#//' $WRAPPER_CONFIG
sed -i "/^wrapper.java.initmemory/s/INIT_MEMORY/$INIT_MEMORY/" $WRAPPER_CONFIG

#Configure page cache
if [ ! -z "$CACHE_MEMORY" ]; then
  sed -i '/dbms.pagecache.memory/s/^#//' $CONFIG_FILE
  sed -i "/dbms.pagecache.memory/s/PAGE_CACHE/$CACHE_MEMORY/" $CONFIG_FILE
fi

echo "==> Global settings"

if [ "$HTTP_LOG" = "true" ]; then
  sed -i '/^org.neo4j.server.http.log.enabled/s/false/true/' $SERVER_CONFIG
fi

if [ "$JMX_ENABLED" = "true" ]; then
  # Check of env variable. Complains+Help if missing
  if [ -z "$JMX_USER" ] || [ -z "$JMX_PASSWORD" ] || [ -z "$JMX_HOSTNAME" ]; then
    echo >&2 "--------------------------------------------------------------------------------"
    echo >&2 "- Missing mandatory JMX_USER and/or JMX_PASSWORD -"
    echo >&2 "--------------------------------------------------------------------------------"
    exit 1
  fi

  sed -i "/^NEO4J_USER/s/NEO4J_USER/$JMX_USER/" $JMX_ACCESS_FILE
  sed -i "/^NEO4J_USER/s/NEO4J_PASSWORD/$JMX_PASSWORD/" $JMX_PASSWORD_FILE
  sed -i "/^NEO4J_USER/s/NEO4J_USER/$JMX_USER/" $JMX_PASSWORD_FILE
  sed -i '/wrapper.java.additional=-Dcom.sun.management.jmxremote/s/^#//' $WRAPPER_CONFIG
  sed -i "/wrapper.java.additional=-Djava.rmi.server.hostname/s/^#//" $WRAPPER_CONFIG
  sed -i "/wrapper.java.additional=-Djava.rmi.server.hostname/s/\$THE_NEO4J_SERVER_HOSTNAME/$JMX_HOSTNAME/" $WRAPPER_CONFIG
fi

echo "==> Server settings"
if [ "$REMOTE_HTTP" = "true" ]; then
  sed -i '/org.neo4j.server.webserver.address/s/^#//' $CONFIG_FILE
fi

if [ "$REMOTE_SHELL" = "true" ]; then
  sed -i '/remote_shell_enabled/s/^#//' $CONFIG_FILE
fi

if [ ! -z "$ES_HOST" ]; then
  mv /tmp/neo4j/plugins/*  /usr/share/neo4j/plugins/
  sed -i '/elasticsearch.host_name/s/^#//' $CONFIG_FILE
  sed -i "s/ES_HOST/http:\/\/$ES_HOST:9200/" $CONFIG_FILE
  sed -i '/elasticsearch.index_spec/s/^#//' $CONFIG_FILE
fi

# Review config (for docker logs)
echo "==> Settings review"
echo
(
echo " --- $(hostname) ---"
echo "Graph settings :"
grep --color -rE "allow_init_cluster|server_id|cluster_server|initial_hosts|\.server=|webserver\.address|database\.mode|wrapper\.java\.additional=" /etc/neo4j/
echo
echo "Network settings :"
ip addr | awk '/inet /{print $2}'
) | awk '{print "   review> "$0}'
echo

echo "==> Starting Neo4J Server (with supervisord)"
echo
touch /tmp/.lock
supervisord -c /etc/supervisor/conf.d/server.conf &
PID=$!
wait $PID
