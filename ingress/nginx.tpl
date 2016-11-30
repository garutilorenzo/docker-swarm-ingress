user  nginx;
worker_processes  1;

error_log /dev/fd/2 warn;
pid /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
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
    {% if 'Labels' in service.Spec and 'ingress.host' in service.Spec.Labels -%}
    server {
        listen 80;
        server_name {{ service.Spec.Labels['ingress.host'] }};

        location / {
            set $service_host {{ service.Spec.Name }};
            set $service_port {{ service.Spec.Labels['ingress.port']|default('80') }};
            set $service_path {{ service.Spec.Labels['ingress.path']|default('/') }};
            proxy_pass http://$service_host:$service_port$service_path;
        }
    }
    {% endif -%}
    {% endfor %}
}
