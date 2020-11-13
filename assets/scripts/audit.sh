#!/bin/sh

echo "Connecting to consul-server and read audit log..."
echo
ssh consul-admin@consul-server sudo cat /var/log/consul/audit-*.json | jq
echo