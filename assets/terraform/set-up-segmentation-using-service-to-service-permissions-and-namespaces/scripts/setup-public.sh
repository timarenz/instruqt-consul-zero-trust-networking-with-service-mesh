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
ExecStart=/usr/local/bin/consul connect envoy -sidecar-for public -namespace api-team -token ${CONSUL_SERVICE_TOKEN} -envoy-binary /usr/local/bin/envoy -- -l debug
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "Moving public service to namespace..."
cat <<-EOF > /etc/consul.d/public-service.json
{
  "service": {
    "name": "public",
    "port": 8080,
    "tags": ["api"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "namespace": "api-team",
    "check": {
      "id": "api",
      "name": "api TCP on port 8080",
      "tcp": "localhost:8080",
      "interval": "3s",
      "timeout": "1s"
    },
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [{
            "destination_name": "product",
            "local_bind_port": 9090
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