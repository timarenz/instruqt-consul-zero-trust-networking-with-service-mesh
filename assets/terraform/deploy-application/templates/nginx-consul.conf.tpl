server {
  listen 8500;
  location / {
    proxy_pass ${consul_http_addr};
    proxy_set_header X-Real-IP $remote_addr;
    proxy_redirect off;
  }
  access_log /var/log/nginx/consul.log;
}