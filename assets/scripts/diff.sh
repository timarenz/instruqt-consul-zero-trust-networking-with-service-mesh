#!/bin/sh

echo "Connecting to frontend-server and reading diffs from configuration files..."
echo
# echo "On the left hand side you see the current Consul service configuration for the frontend services."
# echo "To the right you see the same file but with Consul service mesh enabled for this services."
# echo "In addition an upstream service to the public API will be configured."
echo
ssh consul-admin@frontend-server sudo diff -y /etc/consul.d/frontend-service.json /etc/consul.d/frontend-service.json.example
echo
read -p "Press the ENTER to continue..." REPLY
echo
# echo "To communicate via the service mesh you have to tell your application to connect to the local upstream service."
# echo "This service listens on a defined port on localhost. Below you see the change in the nginx configuration file."
# echo
ssh consul-admin@frontend-server sudo diff -y /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.example
echo
echo "All done."
echo