#!/bin/sh

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

echo "Move envoy service to namespace..."
cat <<EOF > /etc/systemd/system/envoy.service
[Unit]
Description=Envoy
Requires=network-online.target
After=network-online.target
Wants=consul.service

[Service]
Type=simple
ExecStart=/usr/local/bin/consul connect envoy -sidecar-for postgres -namespace db-team -token ${CONSUL_SERVICE_TOKEN} -envoy-binary /usr/local/bin/envoy -- -l debug
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "Moving postgres service to namespace..."
cat <<-EOF > /etc/consul.d/postgres-service.json
{
  "service": {
    "name": "postgres",
    "port": 5432,
    "tags": ["db"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "namespace": "db-team",
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

echo "Reload and start envoy service..."
systemctl daemon-reload && systemctl restart envoy


