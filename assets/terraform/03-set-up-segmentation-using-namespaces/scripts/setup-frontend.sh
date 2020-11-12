#!/bin/sh

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Setup envoy service..."
cat <<EOF > /etc/systemd/system/envoy.service
[Unit]
Description=Envoy
Requires=network-online.target
After=network-online.target
Wants=consul.service

[Service]
Type=simple
ExecStart=/usr/local/bin/consul connect envoy -sidecar-for frontend -namespace frontend-team -token ${CONSUL_SERVICE_TOKEN} -envoy-binary /usr/local/bin/envoy -- -l debug
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "Generating frontend service example configuration..."
cat <<-EOF > /etc/consul.d/frontend-service.json.example
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