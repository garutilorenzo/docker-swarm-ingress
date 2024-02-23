FROM nginx:1.25.0-alpine

RUN apk add --update --no-cache python3 curl bash openssl && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools
RUN pip3 install --no-cache-dir docker jinja2
ENV DOCKER_HOST "unix:///var/run/docker.sock"
ENV UPDATE_INTERVAL "30"
ENV DNS_UPDATE_INTERVAL "5"
ENV DEBUG "false"
ENV USE_REQUEST_ID "true"
ENV LOG_FORMAT "default"
ENV LOG_CUSTOM ""
ENV PROXY_MODE "ssl-passthrough"

ADD ./ingress /ingress
ADD ./docker-entrypoint.sh /docker-entrypoint.sh
ADD index.html /usr/share/nginx/html/index.html
ADD options-ssl-nginx.conf /etc/nginx/options-ssl-nginx.conf
ADD ssl-dhparams.pem /etc/nginx/ssl-dhparams.pem

HEALTHCHECK --interval=10s --timeout=2s --retries=2 \
            CMD curl -A "Docker health check" http://127.0.0.1 && kill -0 `cat /ingress/ingress.pid`

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh /entrypoint.sh # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

WORKDIR /ingress/
CMD [ "python ingress.py" ]
