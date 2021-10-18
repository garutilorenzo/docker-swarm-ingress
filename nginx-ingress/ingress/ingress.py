from docker import Client
from jinja2 import Template

import os, socket
import subprocess
import time

def wait_for_dns_service(services):
    for service in services:
        if service['http_config'] and service['service_name']:
            while True:
                try:
                    ip_address = socket.gethostbyname_ex(service['service_name'])
                    if os.environ['DEBUG'] in ['true', 'yes', '1']:
                        print(ip_address)
                        print('Success')
                    break
                except Exception as e:
                    if os.environ['DEBUG'] in ['true', 'yes', '1']:
                        print('Too early wait')
                        print(e)
                    time.sleep(int(os.environ['DNS_UPDATE_INTERVAL']))

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
    
    services_list = []
    for service in services:
        http_config = False
        https_config = False
        https_redirect = False
        
        virtual_host = ''
        virtual_proto = 'http'
        alt_virtual_host = ''
        service_port = 80
        service_name = ''
        service_id = service.get('ID','')
        
        if service['Spec'].get('Labels'):
            if service['Spec']['Labels'].get('ingress.host'):
                http_config = True
                virtual_host = service['Spec']['Labels'].get('ingress.host')
                alt_virtual_host = service['Spec']['Labels'].get('ingress.alt_host','')
                service_port = service['Spec']['Labels'].get('ingress.port', 80)
                service_name =  service['Spec'].get('Name')

            if service['Spec']['Labels'].get('ingress.ssl') and service['Spec']['Labels'].get('ingress.ssl_redirect'):
                https_config = True
                https_redirect = True
            elif service['Spec']['Labels'].get('ingress.ssl'):
                https_config = True
                https_redirect = False
            
            if service['Spec']['Labels'].get('ingress.virtual_proto'):
                virtual_proto = ervice_port = service['Spec']['Labels'].get('ingress.virtual_proto', 'http')
        
        out = {
            'http_config': http_config,
            'https_config': https_config,
            'https_redirect': https_redirect,
            'virtual_host': virtual_host,
            'virtual_proto': virtual_proto,
            'alt_virtual_host': alt_virtual_host,
            'service_port': service_port,
            'service_name': service_name,
            'service_id': service_id
        }

        services_list.append(out)
    
    new_nginx_config = Template(nginx_config_template).render(
        services = services_list,
        request_id = os.environ['USE_REQUEST_ID'] in ['true', 'yes', '1'],
        proxy_mode = os.environ['PROXY_MODE'], # 'ssl-passthrough, ssl-termination, ssl-bridging
        log_pattern = resolve_pattern(os.environ['LOG_FORMAT'])
    )

    if current_nginx_config != new_nginx_config:
        current_nginx_config = new_nginx_config
        print("[Ingress Auto Configuration] Services have changed, updating nginx configuration...")
        with open(nginx_config_path, 'w') as handle:
            handle.write(new_nginx_config)

        #Wait for all the DNS services are resolved, before reloading nginx
        wait_for_dns_service(services_list)
        
        # Reload nginx with the new configuration
        subprocess.call(['nginx', '-s', 'reload'])

        if os.environ['DEBUG'] in ['true', 'yes', '1']:
            print(new_nginx_config)

    time.sleep(int(os.environ['UPDATE_INTERVAL']))
