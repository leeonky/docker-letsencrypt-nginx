FROM docker

RUN apk update && apk add python bash m4 certbot

ADD tools /opt/tools/

CMD bash /opt/tools/main.sh

