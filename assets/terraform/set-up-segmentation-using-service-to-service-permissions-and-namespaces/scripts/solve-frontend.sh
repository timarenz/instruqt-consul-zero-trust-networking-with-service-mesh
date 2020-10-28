#!/bin/sh

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Moving frontend service to namespace..."
cat <<-EOF > /etc/consul.d/frontend-service.json
{
  "service": {
    "name": "frontend",
    "port": 80,
    "tags": ["web"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "namespace": "frontend-team",
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
            "destination_namespace": "api-team",
            "local_bind_port": 8080
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

echo "Reload and start envoy service..."
systemctl daemon-reload && systemctl restart envoy