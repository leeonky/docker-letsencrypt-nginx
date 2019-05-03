PRJ_PATH=$(dirname "$0")

. tools/lets.sh

. /share/shunit2/src/shunit2_lib
. /share/shunit2/src/shunit2_mock

TEMP_DIR='/tmp/lets'
CONF_PATH="$TEMP_DIR/conf.d/"

setUp() {
	rm -rf $TEMP_DIR
	mkdir -p $CONF_PATH
}

test_remove_useless_http() {
	touch $CONF_PATH/www.baidu.com.https-cert.conf
	touch $CONF_PATH/www.baidu.com.https-serve.conf
	touch $CONF_PATH/www.sina.com.https-cert.conf
	touch $CONF_PATH/www.sina.com.https-serve.conf
	touch $CONF_PATH/www.sina.com.https
	touch $CONF_PATH/www.sohu.com.https-cert.conf
	touch $CONF_PATH/www.sohu.com.https-serve.conf
	touch $CONF_PATH/www.sohu.com.https
	touch $CONF_PATH/www.a.com.conf
	touch $CONF_PATH/www.b.com.conf

	mkdir -p $CONF_PATH/sites
	touch $CONF_PATH/sites/www.sohu.com.https
	touch $CONF_PATH/sites/www.b.com.conf
	touch $CONF_PATH/sites/www.c.com.conf

	remove_domains

	assertFileNotExist $CONF_PATH/www.baidu.com.https-cert.conf
	assertFileNotExist $CONF_PATH/www.baidu.com.https-serve.conf
	assertFileNotExist $CONF_PATH/www.sina.com.https-cert.conf
	assertFileNotExist $CONF_PATH/www.sina.com.https-serve.conf
	assertFileNotExist $CONF_PATH/www.sina.com.https
	assertFileNotExist $CONF_PATH/www.a.com.conf

	assertFileExist $CONF_PATH/www.sohu.com.https-cert.conf
	assertFileExist $CONF_PATH/www.sohu.com.https-serve.conf
	assertFileExist $CONF_PATH/www.sohu.com.https
	assertFileExist $CONF_PATH/www.b.com.conf
	assertFileExist $CONF_PATH/www.c.com.conf
}

test_https_config_content() {
	cat > $CONF_PATH/www.baidu.com.https <<EOF
	server_name www.baidu.com www.b.com;
EOF
	config_domains

	assertGrep 'server_name www.baidu.com www.b.com;' $CONF_PATH/www.baidu.com.https-cert.conf
}

test_obtain_cert_call_certbot_with_right_args() {
	cat > $CONF_PATH/www.baidu.com.https <<EOF
	server_name www.baidu.com www.b.com;
EOF
	LETS_EMAIL=leeonky@gmail.com
	mock_function certbot

	obtain_certs

	mock_verify certbot HAS_CALLED_WITH certonly --webroot -w /var/www-lets/letsencrypt -m leeonky@gmail.com --cert-name www.baidu.com --agree-tos --non-interactive --expand -d www.baidu.com -d www.b.com
}

test_should_create_ssl_conf() {
	cat > $CONF_PATH/www.baidu.com.https <<EOF
	server_name www.baidu.com www.b.com;
EOF
	LETS_EMAIL=leeonky@gmail.com
	mock_function certbot "if [ \$1 == certificates ] && [ \$2 == -d ] && [ \$3 == www.baidu.com ]; then
cat>&2 <<EOF
Saving debug log to /var/log/letsencrypt/letsencrypt.log
openssl not installed, can't check revocation
EOF
cat <<EOF

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Found the following matching certs:
  Certificate Name: www.play-x.fun
    Domains: www.play-x.fun
    Expiry Date: 2019-07-31 15:11:10+00:00 (VALID: 89 days)
    Certificate Path: /etc/letsencrypt/live/www.play-x.fun/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/www.play-x.fun/privkey.pem
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EOF
fi"

	obtain_certs

	assertFileExist $CONF_PATH/www.baidu.com.https-serve.conf

	assertGrep "include ${CONF_PATH}www.baidu.com.https;" $CONF_PATH/www.baidu.com.https-serve.conf
	assertGrep 'ssl_certificate /etc/letsencrypt/live/www.play-x.fun/fullchain.pem;' $CONF_PATH/www.baidu.com.https-serve.conf
	assertGrep 'ssl_certificate_key /etc/letsencrypt/live/www.play-x.fun/privkey.pem;' $CONF_PATH/www.baidu.com.https-serve.conf
}

test_should_remove_certs_by_domain_when_no_serve_conf() {
	mock_function certbot "if [ \$1 == certificates ]; then
cat>&2 <<EOF
Saving debug log to /var/log/letsencrypt/letsencrypt.log
openssl not installed, can't check revocation
openssl not installed, can't check revocation
EOF
cat <<EOF

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Found the following certs:
  Certificate Name: www.t1.play-x.fun
    Domains: www.t1.play-x.fun www.t2.play-x.fun
    Expiry Date: 2019-07-11 14:04:09+00:00 (VALID: 70 days)
    Certificate Path: /etc/letsencrypt/live/www.t1.play-x.fun/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/www.t1.play-x.fun/privkey.pem
  Certificate Name: www.play-x.fun
    Domains: www.play-x.fun
    Expiry Date: 2019-07-18 14:29:06+00:00 (VALID: 77 days)
    Certificate Path: /etc/letsencrypt/live/www.play-x.fun/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/www.play-x.fun/privkey.pem
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EOF
fi"
	echo 'server_name www.t1.play-x.fun;' > $CONF_PATH/www.t1.play-x.fun.https
	echo 'server_name www.play-x.fun;' > $CONF_PATH/www.play-x.fun.https

	remove_certs_by_domain

	mock_verify certbot HAS_CALLED_WITH delete -d www.t2.play-x.fun
	mock_verify certbot NEVER_CALLED_WITH delete -d www.t1.play-x.fun
	mock_verify certbot NEVER_CALLED_WITH delete -d www.play-x.fun
}

test_should_remove_certs_when_no_serve_conf() {
	mock_function certbot "if [ \$1 == certificates ]; then
cat>&2 <<EOF
Saving debug log to /var/log/letsencrypt/letsencrypt.log
openssl not installed, can't check revocation
openssl not installed, can't check revocation
EOF
cat <<EOF
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Found the following certs:
  Certificate Name: www.t1.play-x.fun
    Domains: www.t1.play-x.fun
    Expiry Date: 2019-07-11 14:04:09+00:00 (VALID: 70 days)
    Certificate Path: /etc/letsencrypt/live/www.t1.play-x.fun/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/www.t1.play-x.fun/privkey.pem
  Certificate Name: www.play-x.fun
    Domains: www.play-x.fun
    Expiry Date: 2019-07-18 14:29:06+00:00 (VALID: 77 days)
    Certificate Path: /etc/letsencrypt/live/www.play-x.fun/fullchain.pem
    Private Key Path: /etc/letsencrypt/live/www.play-x.fun/privkey.pem
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
EOF
fi"
	touch $CONF_PATH/www.play-x.fun.https-serve.conf

	remove_certs

	mock_verify certbot HAS_CALLED_WITH delete --cert-name www.t1.play-x.fun
}


. /share/shunit2/src/shunit2

