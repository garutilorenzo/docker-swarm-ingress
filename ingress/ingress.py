from docker import Client
from jinja2 import Template

import os
import subprocess
import time

def resolve_pattern(format):
    if format == 'json':
        return '{ \
"@timestamp": "$time_iso8601", \
"@version": "1", \
"system-type": "ingress", \
"message": "$request [Status: $status]", \
"format": "access", \
"request": { \
  "clientip": "$http_x_forwarded_for", \
  "duration": $request_time, \
  "status": $status, \
  "request": "$request", \
  "path": "$uri", \
  "query": "$query_string", \
  "bytes": $bytes_sent, \
  "method": "$request_method", \
  "host": "$host", \
  "referer": "$http_referer", \
  "user_agent": "$http_user_agent", \
  "request_id": "$request_id", \
  "protocol": "$server_protocol" \
} \
}'
    elif format == 'custom':
        return os.environ['LOG_CUSTOM']
    else:
        return '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" "$http_x_forwarded_for" "$request_id"'

nginx_config_template_path = '/ingress/nginx.tpl'
nginx_config_path = '/etc/nginx/nginx.conf'

with open(nginx_config_path, 'r') as handle:
    current_nginx_config = handle.read()

with open(nginx_config_template_path, 'r') as handle:
    nginx_config_template = handle.read()

cli = Client(base_url = os.environ['DOCKER_HOST'])

while True:
    services = cli.services()

    new_nginx_config = Template(nginx_config_template).render(
        config = services,
        request_id = os.environ['USE_REQUEST_ID'] in ['true', 'yes', '1'],
        log_pattern = resolve_pattern(os.environ['LOG_FORMAT'])
    )

    if current_nginx_config != new_nginx_config:
        current_nginx_config = new_nginx_config
        print "[Ingress Auto Configuration] Services have changed, updating nginx configuration..."
        with open(nginx_config_path, 'w') as handle:
            handle.write(new_nginx_config)

        # Reload nginx with the new configuration
        subprocess.call(['nginx', '-s', 'reload'])

        if os.environ['DEBUG'] in ['true', 'yes', '1']:
            print new_nginx_config

    time.sleep(int(os.environ['UPDATE_INTERVAL']))
