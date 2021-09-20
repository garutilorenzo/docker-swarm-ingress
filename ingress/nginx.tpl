user  nginx;
worker_processes  1;

error_log /dev/fd/2 warn;
pid /var/run/nginx.pid;

events {
    worker_connections  1024;
}

stream {
    map $ssl_preread_server_name $name {
        {% for service in config -%}
        {% if 'Labels' in service.Spec and 'ingress.host' in service.Spec.Labels and 'ingress.ssl' in service.Spec.Labels -%}
        {{ service.Spec.Labels['ingress.host'] }}       backend-{{ service.Spec.Name }};
        {% endif -%}
        {% endfor %}
    }
  
    {% for service in config -%}
    {% if 'Labels' in service.Spec and 'ingress.host' in service.Spec.Labels and 'ingress.ssl' in service.Spec.Labels -%}
    upstream backend-{{ service.Spec.Name }} {
        server {{ service.Spec.Name }}:443;
    }
    {% endif -%}
    {% endfor %}
    proxy_protocol on;
  
    server {
        listen      443;
        proxy_pass  $name;
        ssl_preread on;
    }
}

http {
    resolver 127.0.0.11 ipv6=off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format default '{{ log_pattern }}';
    access_log /dev/fd/1 default;

    sendfile on;
    keepalive_timeout 65;

    {% if request_id -%}
    proxy_set_header Request-Id $request_id;
    add_header Request-Id $request_id;
    {% endif %}

    server {
        listen 80;
        server_name localhost 127.0.0.1;
        access_log off;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }

    {% for service in config -%}
    {% if 'Labels' in service.Spec and 'ingress.host' in service.Spec.Labels and 'ingress.ssl' in service.Spec.Labels and 'ingress.ssl_redirect' in service.Spec.Labels -%}
    server {
        listen 80;
        server_name {{ service.Spec.Labels['ingress.host'] }};

        location / {
            return 301 https://$host$request_uri;
        }
    }
    {% elif 'Labels' in service.Spec and 'ingress.host' in service.Spec.Labels -%}
    server {
        listen 80;
        server_name {{ service.Spec.Labels['ingress.host'] }};

        location / {
            resolver 127.0.0.11;
            set $service_host {{ service.Spec.Name }};
            set $service_port {{ service.Spec.Labels['ingress.port']|default('80') }};
            set $service_path {{ service.Spec.Labels['ingress.path']|default('/') }};
            proxy_pass http://$service_host:$service_port$service_path;
        }
    }
    {% endif -%}
    {% endfor %}
}