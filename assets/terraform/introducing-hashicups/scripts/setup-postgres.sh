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

echo "Starting postgres container..."
mkdir -p /opt/postgres
cat <<-EOF > /opt/postgres/docker-compose.yml
version: '3'
services:
  postgres:
    container_name: "postgres"
    ports:
      - "0.0.0.0:5432:5432"
    environment:
      POSTGRES_DB: "products"
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "password"
    image: "hashicorpdemoapp/product-api-db:v0.0.11"
EOF

/usr/local/bin/docker-compose -f /opt/postgres/docker-compose.yml up -d

echo "Configuring postgres service..."
cat <<-EOF > /etc/consul.d/postgres-service.json
{
  "service": {
    "name": "postgres",
    "port": 5432,
    "tags": ["db"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "check": {
      "id": "db",
      "name": "db TCP on port 5432",
      "tcp": "localhost:5432",
      "interval": "3s",
      "timeout": "1s"
    }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent
