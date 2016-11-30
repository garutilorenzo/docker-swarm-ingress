FROM nginx:1.11-alpine
MAINTAINER Jakob Jarosch <dev@jakobjarosch.de>

RUN apk add --update python py-pip curl; \
    rm -rf /var/cache/apk/*
RUN pip install docker-py jinja2

ENV DOCKER_HOST "unix:///var/run/docker.sock"
ENV UPDATE_INTERVAL "1"
ENV DEBUG "false"

RUN touch /etc/nginx/conf.d/ingress.conf

ADD ./ingress /ingress
ADD ./docker-entrypoint.sh /docker-entrypoint.sh

HEALTHCHECK --interval=10s --timeout=2s --retries=2 \
            CMD curl -A "Docker health check" http://127.0.0.1 && kill -0 `cat /ingress/ingress.pid`

CMD [ "/docker-entrypoint.sh" ]
