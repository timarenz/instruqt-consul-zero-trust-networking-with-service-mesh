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
postgres_server_ip=$(dig +short @127.0.0.1 -p 8600 postgres-server.node.consul)

echo "Generating product configuration..."
mkdir -p /etc/secrets
cat <<-EOF > /etc/secrets/db-creds
{
"db_connection": "host=${postgres_server_ip} port=5432 user=postgres password=password dbname=products sslmode=disable",
  "bind_address": ":9090",
  "metrics_address": ":9103"
}
EOF

echo "Starting product container..."
mkdir -p /opt/product
cat <<-EOF > /opt/product/docker-compose.yml
version: '3'
services:
  product:
    container_name: "product"
    network_mode: "host"
    environment:
      CONFIG_FILE: "/etc/secrets/db-creds"
    image: "hashicorpdemoapp/product-api:v0.0.11"
    volumes:
       - /etc/secrets/db-creds:/etc/secrets/db-creds
EOF

/usr/local/bin/docker-compose -f /opt/product/docker-compose.yml up -d

echo "Configuring product service..."
cat <<-EOF > /etc/consul.d/product-service.json
{
  "service": {
    "name": "product",
    "port": 9090,
    "tags": ["api"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "check": {
      "id": "api",
      "name": "api HTTP on port 9090",
      "http": "http://localhost:9090/coffees",
      "interval": "3s",
      "timeout": "1s"
    }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent
