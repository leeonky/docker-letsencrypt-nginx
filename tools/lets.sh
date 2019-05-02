# /usr/share/deploy/nginx/
#	conf.d
#	www
#	letsencrypt

# 1 remove useless site
# 2 load config
# 3 over write new http config
# 4 restart nginx
# 3 over write new https config
# 5 obtain certs
# 6 restart nginx

# loop for renew certs

# conf 
# www.x.com.https
# www.x.com.https-cert.conf
# www.x.com.https-serve.conf

CONF_PATH="/etc/nginx/conf.d/"
DOMAIN_PATH="/etc/nginx/domain-list/"

remove_domains() {
	for file in $(ls ${CONF_PATH}*https-*.conf 2>/dev/null)
	do
		local conf_file="${file/-cert.conf/}"
		conf_file="${conf_file/-serve.conf/}"
		[ -e "$conf_file" ] || (
			echo "Removing conf for $file..."
			rm "$file"
		)
	done
}

get_server_names() {
	local server_name=$(grep '^[[:blank:]]*server_name' "$1")
	server_name=${server_name/server_name/}
	server_name=$(echo "$server_name" | awk -F\; '{print $1}')
	echo $server_name
}

config_domains() {
	for file in $(ls ${CONF_PATH}*.https 2>/dev/null)
	do
		local server_name=$(get_server_names "$file")
		(
			echo "define(DOMAIN_NAME_LIST, $server_name)"
			cat "$PRJ_PATH/tools/https-cert.m4"
		) | m4 > "${file}-cert.conf"
	done
}

reset_nginx() {
	echo "Restart nginx..."
	docker exec nginx nginx -s reload
}

obtain_certs() {
	local domain_opts=""
	for file in $(ls ${CONF_PATH}*.https 2>/dev/null)
	do
		local server_name=$(get_server_names "$file")
		for url in $server_name
		do
			domain_opts="$domain_opts -d $url"
		done
	done
	certbot certonly --webroot -w /var/www/letsencrypt $domain_opts -m $LETS_EMAIL --agree-tos --non-interactive --expand

	for file in $(ls ${CONF_PATH}*.https 2>/dev/null)
	do
		local server_name=$(get_server_names "$file")
		local first_domain=$(echo $server_name | awk '{print $1}')
		(
			echo "define(CONF_FILE, $file)"
			echo "define(DOMAIN_NAME, $first_domain)"
			cat "$PRJ_PATH/tools/https-serve.m4"
		) | m4 > "${file}-serve.conf"
	done
}

remove_certs() {
	for domain in $(certbot certificates 2>/dev/null | grep 'Certificate Name' | awk '{print $3}')
	do
		[ -e "$CONF_PATH/$domain--serve.conf" ] || certbot delete --cert-name $domain
	done
}

