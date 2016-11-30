
{% for service in config -%}
{% if 'Labels' in service.Spec and 'ingress' in service.Spec.Labels -%}
server {
    listen 80;
    server_name {{ service.Spec.Labels['ingress.host'] }};

    location / {
        proxy_pass http://{{ service.Spec.Name }}:{{ service.Spec.Labels['ingress.port']|default('80') }}{{ service.Spec.Labels['ingress.path']|default('/') }};
    }
}

{% endif -%}
{% endfor -%}
