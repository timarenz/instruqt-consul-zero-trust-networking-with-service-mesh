#!/bin/bash

set -e

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Setting up upstreams for product service..."
cat <<-EOF > /etc/consul.d/product-service.json
{
  "service": {
    "name": "product",
    "port": 9090,
    "tags": ["api"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "check": {
      "id": "api",
      "name": "api TCP on port 9090",
      "tcp": "localhost:9090",
      "interval": "3s",
      "timeout": "1s"
    },
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [{
            "destination_name": "postgres",
            "local_bind_port": 5432
          }]
        }
      }
    }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent

echo "Updating product configuration to use upstreams..."
cat <<-EOF > /etc/secrets/db-creds
{
"db_connection": "host=localhost port=5432 user=postgres password=password dbname=products sslmode=disable",
  "bind_address": ":9090",
  "metrics_address": ":9103"
}
EOF

docker restart product