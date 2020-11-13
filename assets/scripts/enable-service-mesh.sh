#!/bin/sh

echo "Connecting to frontend-server and replacing the configuration files...."
echo
ssh consul-admin@frontend-server sudo cp /etc/consul.d/frontend-service.json.example /etc/consul.d/frontend-service.json
ssh consul-admin@frontend-server sudo cp /etc/nginx/conf.d/default.conf.example /etc/nginx/conf.d/default.conf
ssh consul-admin@frontend-server "sudo systemctl restart consul && sudo systemctl enable envoy && sudo systemctl restart envoy && sudo docker restart frontend"
echo
echo "All done."
echo