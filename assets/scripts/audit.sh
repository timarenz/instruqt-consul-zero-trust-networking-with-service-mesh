#!/bin/sh

echo "Connecting to consul-server and read audit log..."
echo
ssh consul-admin@consul-server sudo tail -f /var/log/consul/audit-*.json | jq
echo