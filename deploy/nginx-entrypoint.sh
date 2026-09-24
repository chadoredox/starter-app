#!/bin/sh
# Génère la config nginx en fonction de $ACTIVE_COLOR puis lance nginx en foreground.
set -e
COLOR="${ACTIVE_COLOR:-blue}"

cat > /etc/nginx/nginx.conf <<NGINX
events { worker_connections 1024; }
http {
    upstream blue  { server app-blue:5000; }
    upstream green { server app-green:5000; }
    server {
        listen 80;
        location / {
NGINX

if [ "$COLOR" = "green" ]; then
    echo "            proxy_pass http://green;" >> /etc/nginx/nginx.conf
else
    echo "            proxy_pass http://blue;" >> /etc/nginx/nginx.conf
fi

cat >> /etc/nginx/nginx.conf <<NGINX
        }
    }
}
NGINX

echo "✅ nginx démarré avec ACTIVE_COLOR=$COLOR → proxy_pass http://$COLOR"
nginx -g 'daemon off;'
