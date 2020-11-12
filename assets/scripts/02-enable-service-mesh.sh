#!/bin/sh

set -e

echo "Connecting to postgres-server..."
echo
echo "On the left hand side you see the current Consul service configurtion for the postgres services."
echo "To the right you see the same file but with Consul service mesh enabled for this services."
echo
ssh consul-admin@postgres-server sudo diff -y /etc/consul.d/postgres-service.json /etc/consul.d/postgres-service.json.example
echo
echo "Next we will enable service mesh for the postgres server by replacing the service configuration file."
read -p "Press any key to continue..." REPLY
echo
ssh consul-admin@postgres-server sudo cp /etc/consul.d/postgres-service.json.example /etc/consul.d/postgres-service.json
echo
echo "Now that the new configuration is in place we will reload Consul and enable the envoy sidecar service on this machine."
echo "Next we will enable service mesh for the postgres server by replacing the service configuration file."
ssh consul-admin@postgres-server "systemctl restart consul && systemctl enable envoy && systemctl restart envoy"
echo
echo "All done."
echo