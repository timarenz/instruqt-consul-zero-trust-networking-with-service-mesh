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
ExecStart=/usr/local/bin/consul connect envoy -gateway=mesh -proxy-id=mesh-gateway -register -address ${MESH_GATEWAY_PRIVATE_IP}:8443 -wan-address ${MESH_GATEWAY_PUBLIC_IP}:8443 -token ${CONSUL_SERVICE_TOKEN} -expose-servers -- -l debug
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "Enable and start envoy service..."
check_consul_agent
systemctl enable envoy && systemctl restart envoy
