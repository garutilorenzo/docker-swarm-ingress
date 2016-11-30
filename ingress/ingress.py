from docker import Client
from jinja2 import Template

import os
import subprocess
import time

nginx_config_template_path = '/ingress/nginx.tpl'
nginx_config_path = '/etc/nginx/conf.d/ingress.conf'

with open(nginx_config_path, 'r') as handle:
    current_nginx_config = handle.read()

with open(nginx_config_template_path, 'r') as handle:
    nginx_config_template = handle.read()

cli = Client(base_url = os.environ['DOCKER_HOST'])

while True:
    services = cli.services()

    new_nginx_config = Template(nginx_config_template).render(config = services)

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
