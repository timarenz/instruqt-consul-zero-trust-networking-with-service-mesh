#!/bin/sh

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Updating postgres service..."
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
    },
    "connect": { "sidecar_service": {} }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent

echo "Enable and start envoy service..."
systemctl enable envoy && systemctl restart envoy