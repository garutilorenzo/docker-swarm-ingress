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

    # If we receive X-Forwarded-Proto, pass it through; otherwise, pass along the
    # scheme used to connect to this server
    map $http_x_forwarded_proto $proxy_x_forwarded_proto {
        default $http_x_forwarded_proto;
        ''      $scheme;
    }
    # If we receive X-Forwarded-Port, pass it through; otherwise, pass along the
    # server port the client connected to
    map $http_x_forwarded_port $proxy_x_forwarded_port {
        default $http_x_forwarded_port;
        ''      $server_port;
    }
    # If we receive Upgrade, set Connection to "upgrade"; otherwise, delete any
    # Connection header that may have been passed to this server
    map $http_upgrade $proxy_connection {
        default upgrade;
        '' close;
    }
    # Apply fix for very long server names
    server_names_hash_bucket_size 128;

    # Set appropriate X-Forwarded-Ssl header based on $proxy_x_forwarded_proto
        map $proxy_x_forwarded_proto $proxy_x_forwarded_ssl {
        default off;
        https on;
    }
    gzip_types text/plain text/css application/javascript application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
        
    # HTTP 1.1 support
    proxy_http_version 1.1;
    proxy_buffering off;
    proxy_set_header Host $http_host;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $proxy_connection;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $proxy_x_forwarded_proto;
    proxy_set_header X-Forwarded-Ssl $proxy_x_forwarded_ssl;
    proxy_set_header X-Forwarded-Port $proxy_x_forwarded_port;

    proxy_set_header Proxy "";

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
    # {{ service.Spec.Labels['ingress.host'] }}
    upstream upstream-{{ service.Spec.Labels['ingress.host'] }} {
        server {{ service.Spec.Name }}:{{ service.Spec.Labels['ingress.port']|default('80') }};
    }
    server {
        server_name {{ service.Spec.Labels['ingress.host'] }};
        listen 80 ;
        location / {
            resolver 127.0.0.11;
            proxy_pass http://upstream-{{ service.Spec.Labels['ingress.host'] }};
        }
    }
    {% endif -%}
    {% endfor %}
}