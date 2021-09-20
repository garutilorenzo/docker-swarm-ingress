FROM nginx:alpine
MAINTAINER Jakob Jarosch <dev@jakobjarosch.de>

RUN apk add --update --no-cache python3 curl && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools
RUN pip3 install docker-py jinja2
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
