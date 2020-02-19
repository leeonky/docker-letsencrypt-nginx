server {
  listen 443 ssl;
  ssl_certificate FULLCHAIN;
  ssl_certificate_key PRIVKEY;
  include CONF_FILE;
}

