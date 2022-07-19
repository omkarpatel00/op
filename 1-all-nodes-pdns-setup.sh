#!/bin/bash

CONF=/etc/pdns/pdns.conf

DATE=`date '+%Y-%m-%d-%H-%M-%S'`


while getopts f:c:C:y:b: flag; do
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
    c)
      if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          #echo "$IP OK"
           CACHEDNS1=$OPTARG;
      else
           echo "Invalid IP Address: $OPTARG, please enter valid IP "
           exit
      fi
        ;;
    C)
      if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          #echo "$IP OK"
           CACHEDNS2=$OPTARG;
      else
           echo "Invalid IP Address: $OPTARG, please enter valid IP "
           exit
      fi
        ;;

    y)
      if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          #echo "$IP OK"
           YELLOW_DNS_SERVER_IP=$OPTARG;
	   yellow_res="$(ip a | egrep -wo $YELLOW_DNS_SERVER_IP)"
	   if [[ -z "$yellow_res" ]]; then
		   echo  -e "Error: $YELLOW_DNS_SERVER_IP is not assigned locally"
		   exit
	   fi
      else
           echo "Invalid IP Address: $OPTARG, please enter valid YELLOW Series DNS IP "
           exit
      fi
        ;;


    b)
      if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          #echo "$IP OK"
           BLUE_DNS_SERVER_IP=$OPTARG;
           blue_res="$(ip a | egrep -wo $BLUE_DNS_SERVER_IP)"
           if [[ -z "$blue_res" ]]; then
                   echo  -e "Error: $BLUE_DNS_SERVER_IP is not assigned locally"
                   exit
           fi
      else
           echo "Invalid IP Address: $OPTARG, please enter valid BLUE Series DNS IP "
           exit
      fi
        ;;

    ?)
      echo -e "usage -f <FQDN> -c <Cache DNS1 IP>  -C <Cache DNS2 IP> -y <YELLOW DNS IP> -b <BLUE DNS IP>"
      exit;
      ;;
  esac
done

shift $(( OPTIND - 1 ));

if [ -z "${DOMAIN}" ] || [ -z "${CACHEDNS1}" ] || [ -z "${CACHEDNS2}" ] || [ -z "${YELLOW_DNS_SERVER_IP}" ] || [ -z "${BLUE_DNS_SERVER_IP}" ]; then
      echo -e "usage -f <FQDN> -c <Cache DNS1 IP>  -C <Cache DNS2 IP> -y <YELLOW DNS IP> -b <BLUE DNS IP>"
     exit;
fi

if [[ "$YELLOW_DNS_SERVER_IP" = "$BLUE_DNS_SERVER_IP" ]]; then
  echo "Error: Green VLAN and Blue VLAN IP's are same, please enter diffrent IP's: Green: $YELLOW_DNS_SERVER_IP Blue: $BLUE_DNS_SERVER_IP "
  exit
fi


allowfrom="127.0.0.0/8"
IPS=`ip -4 addr show scope global | awk '$1 == "inet" {print $2}'`
for i in $IPS
do
	allowfrom=$allowfrom,`ipcalc -n $i | awk -F= '{print $2}'`/`ipcalc -p $i | awk -F= '{print $2}'`
done


    if [ -f "/var/pdns/pdns.sqlite3" ]; then
	mv /var/pdns/pdns.sqlite3 /var/pdns/pdns.sqlite3_$DATE
    fi

    if [ -f "/etc/resolv.conf" ]; then
	mv /etc/resolv.conf /etc/resolv.conf_$DATE
    fi

    echo "search $DOMAIN" > /etc/resolv.conf
    echo "nameserver 127.0.0.1" >> /etc/resolv.conf
 


    mkdir -p /var/pdns/
    VER=`rpm -q pdns-backend-sqlite --qf "%{Version}"`
    sqlite3 /var/pdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite-$VER/schema.sqlite3.sql

    chmod 660 /var/pdns/pdns.sqlite3
    chown pdns:apache /var/pdns/pdns.sqlite3
    chmod 775 /var/pdns/
    chown pdns:apache /var/pdns/

    mv /etc/pdns/pdns.conf /etc/pdns/pdns.conf_$DATE

    touch /etc/pdns/pdns.conf
    chown root:root /etc/pdns/pdns.conf
    chmod 644 /etc/pdns/pdns.conf

    
    chmod 660 /var/pdns/pdns.sqlite3
    chown pdns:apache /var/pdns/pdns.sqlite3
    chmod 775 /var/pdns/
    chown pdns:apache /var/pdns/

    echo "daemon=no" > $CONF
    echo "guardian=no" >> $CONF
    echo "setgid=pdns" >> $CONF
    echo "setuid=pdns" >> $CONF
    echo "launch=gsqlite3" >> $CONF
    echo "gsqlite3-database=/var/pdns/pdns.sqlite3" >> $CONF
    echo "secondary=no" >> $CONF
    echo "primary=yes" >> $CONF
    echo "version-string=dns" >> $CONF
    echo "log-dns-details=on" >> $CONF
    echo "loglevel=3" >> $CONF
    echo "allow-axfr-ips=$allowfrom" >> $CONF
    echo "local-port=53" >> $CONF
    echo "local-address=$YELLOW_DNS_SERVER_IP" >> $CONF
    echo "query-logging=yes" >> $CONF
    echo "allow-unsigned-autoprimary=yes" >> $CONF
    echo "default-soa-content=hostmaster.${DOMAIN} admin.${DOMAIN} 1 10800 3600 604800 3600" >> $CONF

    systemctl enable pdns.service
    systemctl restart pdns.service

    sqlite3 /var/pdns/pdns.sqlite3 < /var/www/html/poweradmin/sql/poweradmin-sqlite-db-structure.sql

    ### echo ctrls.123 | md5sum   ## to get md5 password
    sqlite3 /var/pdns/pdns.sqlite3 'UPDATE users SET password ="59b61663a5c62eca881d8203ea8829d9" WHERE id = "1";'


#################################### Recursor ################################################
    mv /etc/pdns-recursor/recursor.conf /etc/pdns-recursor/recursor.conf_$DATE
    RECUR=/etc/pdns-recursor/recursor.conf

    echo "setuid=pdns-recursor" > $RECUR
    echo "setgid=pdns-recursor" >> $RECUR
    echo "allow-from=$allowfrom" >> $RECUR
    echo "local-address=127.0.0.1,$BLUE_DNS_SERVER_IP" >> $RECUR
    echo "local-port=53" >> $RECUR
    echo "serve-rfc1918=no" >> $RECUR
    echo " " >> $RECUR
    echo "# if multiple ips sperate with ';' if multiple zones seperat with ','" >> $RECUR
    echo " " >> $RECUR
    echo "#forward-zones-recurse=example.org=203.0.113.210:5353;127.0.0.1, powerdns.com=127.0.0.1;198.51.100.10:5353,.=8.8.8.8" >> $RECUR
    echo "forward-zones-recurse=$DOMAIN=$YELLOW_DNS_SERVER_IP,in-addr.arpa=$YELLOW_DNS_SERVER_IP,.=$CACHEDNS1;$CACHEDNS2" >> $RECUR
    echo " " >> $RECUR
    echo "#forward-zones-recurse=" >> $RECUR


    chown root:root $RECUR
    chmod 644 $RECUR

    systemctl enable pdns-recursor
    systemctl restart pdns-recursor
##############################################################################################
    echo -e "Done"

### To notify to slave ####
#pdns_control notify \*

### To fix big in powerdns web gui
if [ ! -f "/usr/bin/pdnssec" ]; then
	ln -s /usr/bin/pdnsutil /usr/bin/pdnssec
fi

systemctl enable httpd
systemctl restart httpd

