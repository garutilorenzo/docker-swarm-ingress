# Ingress Service for Docker Swarm

[![Docker Stars](https://img.shields.io/docker/stars/foxylion/swarm-ingress.svg?style=flat-square)](https://hub.docker.com/r/foxylion/swarm-ingress/) [![Docker Pulls](https://img.shields.io/docker/pulls/foxylion/swarm-ingress.svg?style=flat-square)](https://hub.docker.com/r/foxylion/swarm-ingress/)

This is a minimalistic approach to allow a routing of external requests into a
Docker Swarm while routing based on the public hostname.

Each service which should be routed has so enable the routing using labels.


## The Ingress Service

The ingress service consists of a nginx server and a python script which periodically
updates the nginx configuration. The service communicates with the docker daemon
to retrieve the latest service configuration.

### Run the Service

The Ingress service acts as a reverse proxy in your cluster. It exposes port 80
to the public an redirects all requests to the correct service in background.
It is important that the ingress service can reach other services via the Swarm
network (that means they must share a network).

```
docker service create --name ingress \
  --network ingress-routing \
  -p 80:80 \
  --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
  --constraint node.role==manager \
  foxylion/swarm-ingress
```

It is important to mount the docker socket, otherwise the service can't update
the configuration of nginx.

The ingress service should be scaled to multiple nodes to prevent short outages
when the node with the ingress servic becomes unresponsive (use `--replicas X` when starting the service).

### Register a Service for Ingress

A service can easily be configured using ingress. You must simply provide a label
`ingress.host` which determines the hostname under wich the service should be
publicly available.

## Configuration Labels

Additionally to the hostname you can also map another port and path of your service.
By default a request would be redirected to `http://service-name:80/`.

| Label   | Required | Default | Description |
| ------- | -------- | ------- | ----------- |
| `ingress.host` | `yes` | `-`      | When configured ingress is enabled. The hostname which should be mapped to the service. Wildcards `*` and regular expressions are allowed. |
| `ingress.port` | `no`  | `80`    | The port which serves the service in the cluster. |
| `ingress.path` | `no`  | `/`     | A optional path which is prefixed when routing requests to the service. |

### Run a Service with Enabled Ingress

It is important to run the service which should be used for ingress that it
shares a network. A good way to do so is to create a common network `ingress-routing`
(`docker network create --driver overlay ingress-routing`).

To start a service with ingress simply pass the required labels on creation.

```
docker service create --name my-service \
  --network ingress-routing \
  --label ingress.host=my-service.company.tld \
  nginx
```

It is also possible to later add a service to ingress using `service update`.

```
docker service update \
  --label-add ingress.host=my-service.company.tld \
  --label-add ingress.port=8080 \
  my-service
```
