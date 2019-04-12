server {
  listen 80;
  server_name DOMAIN_NAME_LIST;
  location /.well-known/acme-challenge/ {
    root /var/www/letsencrypt/;
  }
  location / {
    return 301 https://$server_name$request_uri;
  }
}

