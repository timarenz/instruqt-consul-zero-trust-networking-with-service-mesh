#!/bin/sh

echo "Generating frontend example configuration..."
cat <<-EOF > /etc/nginx/conf.d/default.conf.example
# /etc/nginx/conf.d/default.conf
server {
    listen       80;
    server_name  localhost;
    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }
    # Proxy pass the api location to save CORS
    # Use location exposed by Consul connect
    location /api {
        proxy_pass http://localhost:8080;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF

echo "Generating frontend service example configuration..."
cat <<-EOF > /etc/consul.d/frontend-service.json.example
{
  "service": {
    "name": "frontend",
    "port": 80,
    "tags": ["web"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "check": {
      "id": "web",
      "name": "web TCP on port 80",
      "tcp": "localhost:80",
      "interval": "3s",
      "timeout": "1s"
    },
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [{
            "destination_name": "public",
            "local_bind_port": 8080
          }]
        }
      }
    }
  }
}
EOF
