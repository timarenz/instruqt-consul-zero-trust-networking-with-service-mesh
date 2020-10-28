#!/bin/sh

echo "Reconfigure postgres to only listend to 127.0.0.1..."
/usr/local/bin/docker-compose -f /opt/postgres/docker-compose.yml down

cat <<-EOF > /opt/postgres/docker-compose.yml
version: '3'
services:
  postgres:
    container_name: "postgres"
    ports:
      - "127.0.0.1:5432:5432"
    environment:
      POSTGRES_DB: "products"
      POSTGRES_USER: "postgres"
      POSTGRES_PASSWORD: "password"
    image: "hashicorpdemoapp/product-api-db:v0.0.11"
EOF

/usr/local/bin/docker-compose -f /opt/postgres/docker-compose.yml up -d

