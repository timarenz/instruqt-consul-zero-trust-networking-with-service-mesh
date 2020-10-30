#!/bin/sh

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Setting variables..."
local_ipv4=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
public_server_ip=$(dig +short @127.0.0.1 -p 8600 public-server.node.consul)

echo "Generating frontend configuration..."
mkdir -p /etc/nginx/conf.d
cat <<-EOF > /etc/nginx/conf.d/default.conf
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
        proxy_pass http://${public_server_ip}:8080;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOF

echo "Starting frontend container..."
mkdir -p /opt/frontend
cat <<-EOF > /opt/frontend/docker-compose.yml
version: '3'
services:
  frontend:
    container_name: "frontend"
    network_mode: "host"
    image: "hashicorpdemoapp/frontend:v0.0.3"
    volumes:
       - /etc/nginx/conf.d/:/etc/nginx/conf.d/
EOF

/usr/local/bin/docker-compose -f /opt/frontend/docker-compose.yml up -d

echo "Stopping Consul agent..."
systemctl stop consul || true

echo "Configuring frontend service..."
cat <<-EOF > /etc/consul.d/frontend-service.json
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
    }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent