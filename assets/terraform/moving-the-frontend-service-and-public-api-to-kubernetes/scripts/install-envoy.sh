#!/bin/sh

set -e

echo "Installing envoy..."
sudo curl -L https://getenvoy.io/cli | sudo bash -s -- -b /usr/local/bin
sudo getenvoy fetch standard:1.14.4
sudo cp ~/.getenvoy/builds/standard/1.14.4/linux_glibc/bin/envoy /usr/local/bin/envoy
