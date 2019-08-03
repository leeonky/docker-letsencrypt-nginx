set -x
PRJ_PATH=$(dirname "$0")/../

. ${PRJ_PATH}/tools/lets.sh

echo "======== Start process certs $(date) ========="
remove_domains &&\
config_domains &&\
reset_nginx &&\
remove_certs &&\
obtain_certs &&\
reset_nginx
echo ================ Process done ======================

while true
do
	certbot renew --deploy-hook reset_nginx
	sleep 3600
done
