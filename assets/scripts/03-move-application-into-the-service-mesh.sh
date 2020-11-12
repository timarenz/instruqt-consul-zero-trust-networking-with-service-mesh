#!/bin/sh

set -e

echo "Connecting to frontend-server..."
echo
echo "On the left hand side you see the current Consul service configurtion for the frontend services."
echo "To the right you see the same file but with a namespaces configured for this services."
echo
ssh consul-admin@frontend-server sudo diff -y /etc/consul.d/frontend-service.json /etc/consul.d/frontend-service.json.example
echo
echo "Now we replace the old with the new file."
read -p "Press any key to continue..." REPLY
echo
ssh consul-admin@frontend-server sudo cp /etc/consul.d/frontend-service.json.example /etc/consul.d/frontend-service.json
echo
echo "Now that the new configuration is in place we will reload Consul and Envoy sidecar on this machine."
echo
ssh consul-admin@frontend-server "systemctl restart consul && sudo systemctl daemon-reload && systemctl restart envoy"
echo
echo "All done."
echo