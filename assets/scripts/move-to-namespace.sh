#!/bin/sh

echo "Connecting to frontend-server and showing the configuration files...."
echo
ssh consul-admin@frontend-server sudo diff -y /etc/consul.d/frontend-service.json /etc/consul.d/frontend-service.json.example
echo
echo "Next we put the file into place and reload the required services."
read -p "Press any key to continue..." REPLY
echo
ssh consul-admin@frontend-server sudo cp /etc/consul.d/frontend-service.json.example /etc/consul.d/frontend-service.json
ssh consul-admin@frontend-server "sudo systemctl restart consul && sudo systemctl daemon-reload && sudo systemctl restart envoy"
echo
echo "All done."
echo