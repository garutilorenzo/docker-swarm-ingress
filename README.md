# Ingress Service for Docker Swarm

[![Docker Stars](https://img.shields.io/docker/stars/foxylion/swarm-ingress.svg?style=flat-square)](https://hub.docker.com/r/foxylion/swarm-ingress/) [![Docker Pulls](https://img.shields.io/docker/pulls/foxylion/swarm-ingress.svg?style=flat-square)](https://hub.docker.com/r/foxylion/swarm-ingress/)

This is a minimalistic approach to allow a routing of external requests into a
Docker Swarm while routing based on the public hostname.

Each service which should be routed has so enable the routing using labels.


## Start the Ingress Service

The ingress service consists of a nginx server and a python script which periodically
updates the nginx configuration.

```
docker service create --name ingress \
  --net ingress-routing \
  -p 80:80 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  foxylion/swarm-ingress
```

The ingress service should be scaled to multiple nodes to prevent short outages
when the node with the ingress services becomes unresponsive.

## Configuration Labels

| Label   | Required | Default | Description |
| ------- | -------- | ------- | ----------- |
| `ingress`      | `-`  | `false` | When set to true ingress is activated for this service. |
| `ingress.host` | `yes` | `-`     | The hostname which should be mapped to the service. Wildcards `*` and regular expressions are allowed. |
| `ingress.port` | `no`  | `80`    | The port which serves the service in the cluster. |
| `ingress.path` | `no`  | `/`     | A optional path which is prefixed when routing requests to the service. |

### Example

```
docker service create --name my-service \
  --net ingress-routing \
  --label ingress=true \
  --label ingress.host=my-service.company.tld \
  nginx
```
