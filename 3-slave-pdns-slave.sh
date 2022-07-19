#!/bin/bash

CONF=/etc/pdns/pdns.conf

DATE=`date '+%Y-%m-%d-%H-%M-%S'`

while getopts f:m: flag; do
  case $flag in
    f)
        fqdn=$OPTARG
        result=`echo $fqdn | grep -P '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)'`
        if [[ -z "$result" ]]
        then
            echo "$fqdn is NOT a FQDN"
            exit
        else
            DOMAIN=$OPTARG
        fi
        ;;
    m)
      if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          #echo "$IP OK"
           MASTERDNSIP=$OPTARG;
      else
           echo "Invalid IP Address: $OPTARG, please enter valid IP "
           exit
      fi
        ;;
    ?)
      echo -e "usage -f <FQDN> -m <Master YELLOW DNS IP>"
      exit;
      ;;
  esac
done

shift $(( OPTIND - 1 ));

if [ -z "${DOMAIN}" ] || [ -z "${MASTERDNSIP}" ]; then
     echo -e "usage -f <FQDN> -m <Master YELLOW DNS IP>"
     exit;
fi

hostnamectl set-hostname ns2.$DOMAIN


    if [ -f "/var/pdns/pdns.sqlite3" ]; then
	rm -rf  /var/pdns/pdns.sqlite3 
    fi
    	
    mkdir -p /var/pdns/
    FQDN=ns2.${DOMAIN}
    VER=`rpm -q pdns-backend-sqlite --qf "%{Version}"`
    sqlite3 /var/pdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite-$VER/schema.sqlite3.sql
    sqlite3 /var/pdns/pdns.sqlite3 "insert into supermasters values('$MASTERDNSIP','$FQDN','admin');"

    cp /etc/pdns/pdns.conf /etc/pdns/pdns.conf_$DATE
    chown root:root /etc/pdns/pdns.conf
    chmod 644 /etc/pdns/pdns.conf


    chown pdns:pdns /var/pdns/
    chmod 770 /var/pdns/
    chown pdns:pdns /var/pdns/pdns.sqlite3
    chmod 660 /var/pdns/pdns.sqlite3

    grep -q '^secondary=' $CONF && sed -i 's/^secondary=.*/secondary=yes/' $CONF || echo 'secondary=yes' >> $CONF
    grep -q '^primary=' $CONF && sed -i 's/^primary=.*/primary=no/' $CONF || echo 'primary=no' >> $CONF
    grep -q '^autosecondary' $CONF && sed -i 's/^autosecondary.*/autosecondary=yes/' $CONF || echo 'autosecondary=yes' >> $CONF
    grep -q '^allow-notify-from=' $CONF && sed -i "s/^allow-notify-from=.*/allow-notify-from=${MASTERDNSIP}/" $CONF || echo "allow-notify-from=${MASTERDNSIP}" >> $CONF

    systemctl enable pdns.service
    systemctl restart pdns.service

#################################### 
    systemctl enable pdns-recursor
    systemctl restart pdns-recursor
#####################################
    systemctl disable httpd
    systemctl stop httpd

    echo -e " "
    echo -e "Done"


