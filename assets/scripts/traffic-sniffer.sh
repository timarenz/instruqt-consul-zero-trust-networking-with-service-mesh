#!/bin/sh

set -e

echo "Connecting to postgres-server and start sniffing traffic..."
# echo
# echo "Below you see that currently the postgres-services is listening on 0.0.0.0:5432. So anyone in the network can access this services."
# echo
# ssh consul-admin@postgres-server sudo netstat -tulpn
# echo
# echo "Next we dump the traffic of the postgres-services port. If you look closely you will see SQL statements in clear text. To stop the traffic sniffing press Control+C (Mac) or Strg+C (PC)."
# read -p "Press any key to continue..." REPLY
echo
ssh consul-admin@postgres-server sudo tcpdump -nX -i ens4 port 5432 or port 21000
echo
echo "All done."
echo