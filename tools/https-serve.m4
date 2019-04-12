server {
  listen 443 ssl;
  ssl_certificate /etc/letsencrypt/live/DOMAIN_NAME/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/DOMAIN_NAME/privkey.pem;
  include CONF_FILE;
}

