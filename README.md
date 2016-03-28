# Neo4j Cluster

## Docker Container

The frontend docker container `wayblazer/neo4j-cluster` runs the node application using Supervisord to manage the process. Notes on the container and configuration:

- Edit `supervisord.conf` to configure logging details for the jetty process.
- `run.sh` handles options to the container and bootstrapping for the container. It's a good place to see under the hood of the container.
- Data is written to the `/data` volume.
- Logs are written to the `/logs` volume.
- Authentication file (`auth`) can be mounted to `/var/lib/neo4j/data/dbms`.

**Authentication**

When you initially login to neo, it creates a file called `auth` in `/var/lib/neo4j/data/dbms`. It contains users and hashed passwords. To carry usernames and passwords across containers, you can store this file on your local system and mount it into the container via a volume. **If you do not do this, when you recreate a container, you will need to reset the user/password through the web ui.**

**Running the Container:**

Required environment variables (`-e`):
- SERVER_ID: An integer uniquely identifying the server in the cluster.

Optional environment variables:
- `ES_HOST`: The hostname of the elasticsearch host, if needed for indexing.
- `ES_PORT`: The port of the elasticsearch service, if needed for indexing.
- `CLUSTER_NODES`: A comma separated list of hostnames that should make up the cluster. Includes the current servers hostname. Ex: `neo1.local,neo2.local,neo3.local`.
- `ARBITER`: `true` or `false`. Whether to launch this server as an arbiter. [default=False]
- `REMOTE_HTTP`: `true` or `false`. Enables web interface / http.
- `REMOTE_SHELL`: `true` or `false`. Enables remote shell access.
- `JMX_ENABLED`: `true` or `false`. Enables JMX on port 9999. If `true` requires below user/pass/hostname env vars. `false` by default.
- `JMX_USER`: Readonly User (role) to access JMX by.
- `JMX_PASSWORD`: Password allowing readonly access to JMX.
- `JMX_HOSTNAME`: The hostname/ip that you will be using to access JMX (usually the ip or hostname of the server).
- `HTTP_LOG`: `true` or `false`. Enables HTTP logs for the rest api to be written to `/logs`.

### Single HA Server

You can launch the server as a single, HA cluster node (*not* `SINGLE` mode).  You can use the docker-compose file in the root of the directory to do this. You must have a local docker environment (see docker-machine on Google) for this to work.

Build the container from its current state.
`docker-compose build`

Run it.
`docker-compose up -d`

Check the logs.
`docker-compose logs`

### Multi-node HA Cluster

(Docker-compose to come.)

When launching multiple you need to provide both the SERVER_ID and the CLUSTER_NODES. The servers will not become available until both servers have registered with one another. Also note that if these are on the same host, they will need to store data and logs in different physical locations.

**Plain ol' Docker Example:**

```
docker run -h neo1 -d -v ./logs/master:/logs -v ./data_master:/data -p 7474:7474 -e SERVER_ID=1 -e MODE=HA -e CLUSTER_NODES=neo1,neo2 wayblazer/neo4j-cluster

docker run -h neo2 -d -v ./logs/slave:/logs -v ./data_slave:/data -p 7474:7474 -e SERVER_ID=2 -e MODE=HA -e CLUSTER_NODES=neo1,neo2 wayblazer/neo4j-cluster
```
