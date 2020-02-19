# /usr/share/deploy/nginx/
#	conf.d/sites
#	www-lets
#	letsencrypt

CONF_PATH="/etc/nginx/conf.d/"
DOMAIN_PATH="/etc/nginx/domain-list/"

remove_useless_domains() {
	for file in $(find ${CONF_PATH} -maxdepth 1 -type f 2>/dev/null)
	do
		local conf_file="${file/-cert.conf/}"
		conf_file="${conf_file/-serve.conf/}"
		local file_name=$(basename "$conf_file")
		[ -e "$CONF_PATH/sites/$file_name" ] || (
			echo "Removing conf for $file..."
			rm -f "$file"
		)
	done

	for file in $(find ${CONF_PATH}/sites -maxdepth 1 -type f 2>/dev/null)
	do
		cp $file $CONF_PATH/
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
			cat "$PRJ_PATH/tools/m4s/https-cert.m4"
		) | m4 > "${file}-cert.conf"
	done
}

reset_nginx() {
	echo "Restart nginx..."
	docker exec nginx nginx -s reload
}

obtain_certs() {
	for file in $(ls ${CONF_PATH}*.https 2>/dev/null)
	do
		local domain_opts=""
		local server_name=$(get_server_names "$file")
		local first_domain=$(echo $server_name | awk '{print $1}')
		local cert_name=$(basename ${file/.https/})
		for url in $server_name
		do
			domain_opts="$domain_opts -d $url"
		done

		certbot certonly --webroot -w /var/www-lets/letsencrypt -m $LETS_EMAIL --cert-name $cert_name --agree-tos --non-interactive --expand $domain_opts

		local cert_path=$(certbot certificates -d $first_domain 2>/dev/null | grep 'Path:' | awk -F\: '{print $2}' | awk '{print $1}')
		local fullchain_path=$(echo "$cert_path" | grep fullchain)
		local privkey_path=$(echo "$cert_path" | grep privkey)
		(
			echo "define(CONF_FILE, $file)"
			echo "define(FULLCHAIN, $fullchain_path)"
			echo "define(PRIVKEY, $privkey_path)"
			cat "$PRJ_PATH/tools/m4s/https-serve.m4"
		) | m4 > "${file}-serve.conf"
	done
}

is_domain_exist() {
	for file in $(ls ${CONF_PATH}*.https 2>/dev/null)
	do
		local server_name=$(get_server_names "$file")
		for url in $server_name
		do
			if [ $url == $1 ]; then
				return 0
			fi
		done
	done
	return 1
}

remove_useless_certs_by_domain() {
	for domain in $(certbot certificates 2>/dev/null| grep 'Domains:' | awk -F\: '{print $2}')
	do
		is_domain_exist $domain || certbot delete -d $domain
		certbot certificates
	done
}

remove_useless_certs() {
	for domain in $(certbot certificates 2>/dev/null | grep 'Certificate Name' | awk '{print $3}')
	do
		[ -e "$CONF_PATH/$domain.https-serve.conf" ] || certbot delete --cert-name $domain
	done
	certbot certificates
}

