#!/bin/bash

set -e

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Setting variables..."
local_ipv4=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
product_server_ip=$(dig +short @127.0.0.1 -p 8600 product-server.node.consul)

echo "Starting public container..."
mkdir -p /opt/public
cat <<-EOF > /opt/public/docker-compose.yml
version: '3'
services:
  public:
    container_name: "public"
    network_mode: "host"
    environment:
      BIND_ADDRESS: ":8080"
      PRODUCT_API_URI: "http://${product_server_ip}:9090"
    image: "hashicorpdemoapp/public-api:v0.0.1"
EOF

/usr/local/bin/docker-compose -f /opt/public/docker-compose.yml up -d

echo "Configuring public service..."
cat <<-EOF > /etc/consul.d/public-service.json
{
  "service": {
    "name": "public",
    "port": 8080,
    "tags": ["api"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "check": {
      "id": "api",
      "name": "api TCP on port 8080",
      "tcp": "localhost:8080",
      "interval": "3s",
      "timeout": "1s"
    }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent