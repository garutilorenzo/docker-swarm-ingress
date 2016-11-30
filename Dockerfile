FROM nginx:1.11-alpine
MAINTAINER Jakob Jarosch <dev@jakobjarosch.de>

RUN apk add --update python py-pip curl; \
    rm -rf /var/cache/apk/*
RUN pip install docker-py jinja2

ENV DOCKER_HOST "unix:///var/run/docker.sock"
ENV UPDATE_INTERVAL "1"
ENV DEBUG "false"
ENV USE_REQUEST_ID "true"
ENV LOG_FORMAT "default"
ENV LOG_CUSTOM ""

ADD ./ingress /ingress
ADD ./docker-entrypoint.sh /docker-entrypoint.sh
ADD index.html /usr/share/nginx/html/index.html

HEALTHCHECK --interval=10s --timeout=2s --retries=2 \
            CMD curl -A "Docker health check" http://127.0.0.1 && kill -0 `cat /ingress/ingress.pid`

CMD [ "/docker-entrypoint.sh" ]
