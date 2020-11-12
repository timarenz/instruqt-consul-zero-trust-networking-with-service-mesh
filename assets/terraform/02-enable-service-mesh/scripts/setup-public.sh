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
ExecStart=/usr/local/bin/consul connect envoy -sidecar-for public -token ${CONSUL_SERVICE_TOKEN} -envoy-binary /usr/local/bin/envoy -- -l debug
ExecReload=/bin/kill -HUP $MAINPID
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "Setting up upstreams for public service..."
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

echo "Enable and start envoy service..."
systemctl enable envoy && systemctl restart envoy

echo "Updating public configuration to use upstreams..."
/usr/local/bin/docker-compose -f /opt/public/docker-compose.yml down

cat <<-EOF > /opt/public/docker-compose.yml
version: '3'
services:
  public:
    container_name: "public"
    network_mode: "host"
    environment:
      BIND_ADDRESS: ":8080"
      PRODUCT_API_URI: "http://localhost:9090"
    image: "hashicorpdemoapp/public-api:v0.0.1"
EOF

/usr/local/bin/docker-compose -f /opt/public/docker-compose.yml up -d