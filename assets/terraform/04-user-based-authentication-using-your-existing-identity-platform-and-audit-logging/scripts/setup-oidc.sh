#!/bin/bash

set -e

check_consul_agent() {
  until (curl http://127.0.0.1:8500/v1/status/leader 2>/dev/null | grep -E '".+"'); do
    echo "Waiting for Consul agent startup..."
    sleep 1
  done
  return 0
}

check_oidc_service() {
  while [ -z "$(curl -s -k http://127.0.0.1:9000/.well-known/openid-configuration)" ]; do
    echo "Waiting for OIDC service startup..."
    sleep 1
  done
  return 0
}

echo "Setting variables..."
local_ipv4=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)

echo "Generating oidc config..."
mkdir -p /opt/oidc/config
mv /tmp/oidc-config.json /opt/oidc/config/config.json
# cat <<-EOF > /opt/oidc/config/config.json
# {
#   "idp_name": "${oidc_discovery_url}",
#   "port": 9000,
#   "client_config": [
#     {
#       "client_id": "foo",
#       "client_secret": "bar",
#       "redirect_uris": [
#         "${oidc_redirect_url_1}",
#         "${oidc_redirect_url_2}"
#       ]
#     }
#   ],
#   "claim_mapping": {
#     "openid": [ "sub" ],
#     "email": [ "email", "email_verified" ],
#     "profile": [ "name", "nickname" ],
#     "groups": [ "groups" ]
#   }
# }
# EOF

cat <<-EOF > /opt/oidc/config/users.json
[
  {
    "id": "SIMPLE_OIDC_USER_JEFF",
    "email": "jeff@hashicorp.example",
    "email_verified": true,
    "name": "jeff",
    "nickname": "jeff",
    "password": "password",
    "groups": ["everyone", "db-team"]
  },
  {
    "id": "SIMPLE_OIDC_USER_TIM",
    "email": "tim@hashicorp.examplei",
    "email_verified": true,
    "name": "tim",
    "nickname": "tim",
    "password": "password",
    "groups": ["everyone", "api-team"]
  },
  {
    "id": "SIMPLE_OIDC_USER_TIM",
    "email": "patrick@hashicorp.examplei",
    "email_verified": true,
    "name": "patrick",
    "nickname": "patrick",
    "password": "password",
    "groups": ["everyone", "frontend-team"]
  },
  {
    "id": "SIMPLE_OIDC_USER_CPU",
    "email": "cpu@hashicorp.example",
    "email_verified": true,
    "name": "cpu",
    "nickname": "cpu",
    "password": "password",
    "groups": ["everyone", "admin"]
  }
]
EOF

echo "Starting oidc container..."
cat <<-EOF > /opt/oidc/docker-compose.yml
version: '3.6'
services:
  simple-oidc-provider:
    container_name: simple-oidc-provider
    hostname: simple-oidc-provider
    image: qlik/simple-oidc-provider
    volumes:
      - /opt/oidc/config/:/config/
    environment:
      - USERS_FILE=/config/users.json
      - CONFIG_FILE=/config/config.json
    ports:
      - "9000:9000"
EOF

/usr/local/bin/docker-compose -f /opt/oidc/docker-compose.yml up -d

check_oidc_service

echo "Configuring oidc service..."
cat <<-EOF > /etc/consul.d/oidc-service.json
{
  "service": {
    "name": "oidc",
    "port": 9000,
    "tags": ["mgmt"],
    "token": "${CONSUL_SERVICE_TOKEN}",
    "check": {
      "id": "oidc",
      "name": "oidc TCP on port 9000",
      "tcp": "localhost:9000",
      "interval": "3s",
      "timeout": "1s"
    }
  }
}
EOF

echo "(Re)starting Consul agent..."
systemctl restart consul
check_consul_agent
