user  nginx;
worker_processes  1;

error_log /dev/fd/2 warn;
pid /var/run/nginx.pid;

events {
    worker_connections  1024;
}

{% if proxy_mode == 'ssl-passthrough' -%}
stream {
    map $ssl_preread_server_name $name {
        {% for service in services -%}
        {% if service['https_config'] and proxy_mode == 'ssl-passthrough' -%}
        {{ service['virtual_host'] }}       backend-{{ service['service_name'] }};
        {% endif -%}
        {% endfor %}
    }
  
    {% for service in services -%}
    {% if service['https_config'] and proxy_mode == 'ssl-passthrough' -%}
    # {{ service['virtual_host'] }} - {{ service['service_id'] }} - HTTPS Passthrough
    upstream backend-{{ service['service_name'] }} {
        server {{ service['service_name'] }}:443;
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
{% endif %}

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
        server_name _;
        access_log off;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    
    {% if proxy_mode not in ['ssl-passthrough'] -%}
    server {
        server_name _;
        listen 443 ssl http2 ;
        
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";

        charset utf-8;

        # SSL Settings        
        ssl_certificate /etc/nginx/default.crt;
        ssl_certificate_key /etc/nginx/default.key;
       
        include /etc/nginx/options-ssl-nginx.conf;
        ssl_dhparam /etc/nginx/ssl-dhparams.pem;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    {% endif %}

    {% for service in services -%}
    {% if service['https_redirect'] -%}
    server {
        listen 80;
        server_name {{ service['virtual_host']  }};

        location / {
            return 301 https://$host$request_uri;
        }
    }
    {% endif -%}
    {% if service['https_config'] and proxy_mode not in ['ssl-passthrough'] -%}

    # {{ service['virtual_host']  }} - {{  service['id'] }} - HTTPS ssl-termination/ssl-bridging
    upstream upstream-https-{{ service['virtual_host'] }} {
        server {{ service['service_name'] }}:{{ service['service_port']|default('80') }};
    }

    server {
        server_name {{ service['virtual_host'] }};
        listen 443 ssl http2 ;
        
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";

        charset utf-8;

        # SSL Settings        
        ssl_certificate /run/secrets/{{ service['virtual_host'] }}.crt;
        ssl_certificate_key /run/secrets/{{ service['virtual_host'] }}.key;
       
        include /etc/nginx/options-ssl-nginx.conf;
        ssl_dhparam /etc/nginx/ssl-dhparams.pem;

        location / {
            resolver 127.0.0.11;
            set $virtual_proto {{ service.virtual_proto }};
            proxy_pass $virtual_proto://upstream-https-{{ service['virtual_host'] }};
        }
    }
    {% elif service['http_config'] -%}

    # {{ service['virtual_host'] }} - {{ service['service_id'] }} - HTTP
    upstream upstream-{{ service['virtual_host'] }} {
        server {{ service['service_name'] }}:{{ service['service_port']|default('80') }};
    }

    server {
        server_name {{ service['virtual_host'] }};
        listen 80 ;
        
        charset utf-8;
        
        location / {
            resolver 127.0.0.11;
            set $virtual_proto {{ service.virtual_proto }};
            proxy_pass $virtual_proto://upstream-{{ service['virtual_host'] }};
        }
    }
    {% endif -%}
    {% endfor %}
}