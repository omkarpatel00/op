#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'
DATE=`date '+%Y-%m-%d-%H-%M-%S'`

DOMAIN=""
RDNS=""

CLEAR_ZONES()
{
 for ZONE in `pdnsutil list-all-zones`
 do
    pdnsutil delete-zone $ZONE
 done
}


while getopts m:s:f: flag; do
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
           MASTERIP=$OPTARG;
      else
           echo "Invalid IP Address: $OPTARG, please enter valid master IP "
           exit
      fi
        ;;
    s)
      if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          #echo "$IP OK"
           SLAVEIP=$OPTARG;
      else
           echo "Invalid IP Address: $OPTARG, please enter valid slave IP "
           exit
      fi
        ;;
    ?)
      echo -e "usage -f <FQDN> -m <YELLOW MASTER IP> -s <YELLOW SLAVE IP>"
      exit;
      ;;
  esac
done

shift $(( OPTIND - 1 ));

if [ -z "${DOMAIN}" ] || [ -z "${MASTERIP}" ] || [ -z "${SLAVEIP}" ]; then
     echo -e "usage -f <FQDN> -m <YELLOW MASTER IP> -s <YELLOW SLAVE IP>"
     exit;
fi

if [ ! -f "/tmp/records" ]; then
        echo -e "\n/tmp/records DNS records file not found\n"
	echo -e "create a file /tmp/records in below format\n"
	echo -e "system01,A,1.1.1.1\n"
	echo -e "system02,CNAME,system01.$DOMAIN\n"
	exit
fi

hostnamectl set-hostname ns1.$DOMAIN

#printf  "Please find Slave name server FQDN: ${RED} ns2.$DOMAIN \n ${NC}"
#echo -e ""
CONF=/etc/pdns/pdns.conf

grep -q '^only-notify=' $CONF && sed -i "s/^only-notify=.*/only-notify=${SLAVEIP}/" $CONF || echo "only-notify=${SLAVEIP}" >> $CONF


/usr/bin/pdnsutil create-zone $DOMAIN > /dev/null
/usr/bin/pdnsutil add-record $DOMAIN . NS ns1.$DOMAIN > /dev/null
/usr/bin/pdnsutil add-record $DOMAIN . NS ns2.$DOMAIN > /dev/null
/usr/bin/pdnsutil add-record $DOMAIN ns1 A $MASTERIP > /dev/null
/usr/bin/pdnsutil add-record $DOMAIN ns2 A $SLAVEIP > /dev/null

pdnsutil set-meta $DOMAIN SOA-EDIT-API DEFAULT

cat /tmp/records  | head -1 > /tmp/yellow
RDNS=$(cat /tmp/yellow |awk -F, '{print $3}'| sed -r 's/([^.]+)\.([^.]+)\.([^.]+)\.([^ ]+)/\3\.\2\.\1/')

/usr/bin/pdnsutil create-zone $RDNS.in-addr.arpa > /dev/null
/usr/bin/pdnsutil add-record $RDNS.in-addr.arpa . NS ns1.$DOMAIN > /dev/null
/usr/bin/pdnsutil add-record $RDNS.in-addr.arpa . NS ns2.$DOMAIN > /dev/null


pdnsutil set-meta $RDNS.in-addr.arpa SOA-EDIT-API DEFAULT


while read line
do
	echo $line > /tmp/yellow

	HSTNAME=$(cat /tmp/yellow |awk -F, '{print $1}')
	if [[ "$HSTNAME" =~ [^a-zA-Z0-9] ]]; then
  		echo -e "$HSTNAME is in valid"
  	        if [ -f "/var/pdns/pdns.sqlite3" ]; then
 		        cp /var/pdns/pdns.sqlite3 /var/pdns/pdns.sqlite3_$DATE
		fi
		CLEAR_ZONES
		exit
	fi
	DNS_RECORD_TYPE=$(cat /tmp/yellow |awk -F, '{print $2}')
	if [[ "$DNS_RECORD_TYPE" == "A" ]] || [[ "$DNS_RECORD_TYPE" == "CNAME" ]]; then
		echo "" > /dev/null
	else
  		echo "Invalid DNS_RECORD_TYPE: $DNS_RECORD_TYPE"
		CLEAR_ZONES
		exit
	fi

	if [[ "$DNS_RECORD_TYPE" == "A" ]]; then
	
		IPADDR=$(cat /tmp/yellow |awk -F, '{print $3}')
		if [[ $IPADDR =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        	  #echo "$IP OK"
	          IPADDR=$IPADDR
        	else
	           echo "Invalid IP Address: $IPADDR"
		   CLEAR_ZONES
	           exit
        	fi

		RDNS=$(cat /tmp/yellow |awk -F, '{print $3}'| sed -r 's/([^.]+)\.([^.]+)\.([^.]+)\.([^ ]+)/\3\.\2\.\1/')
		FRDNS=$(cat /tmp/yellow |awk -F, '{print $3}'| sed -r 's/([^.]+)\.([^.]+)\.([^.]+)\.([^ ]+)/\4/')
		if [ "$FRDNS" -ge 1 ] && [ "$FRDNS" -le 254 ]; then
	    		echo "" > /dev/null
		else
    			echo "not valid number, try again: $FRDNS"
			CLEAR_ZONES
			exit
		fi

		RDNSHST=$HSTNAME.$DOMAIN

		/usr/bin/pdnsutil add-record $DOMAIN  $HSTNAME $DNS_RECORD_TYPE $IPADDR > /dev/null
		echo -e "Adding record: $HSTNAME $IPADDR"
		/usr/bin/pdnsutil add-record $RDNS.in-addr.arpa $FRDNS PTR $RDNSHST > /dev/null
		echo -e "Adding record: $RDNS.in-addr.arpa $RDNSHST"
		sleep 1
	fi

	if [[ "$DNS_RECORD_TYPE" == "CNAME" ]]; then
		IPADDR=$(cat /tmp/yellow |awk -F, '{print $3}')
		/usr/bin/pdnsutil add-record $DOMAIN  $HSTNAME $DNS_RECORD_TYPE $IPADDR > /dev/null
		 echo -e "Adding record: $HSTNAME $IPADDR"
		sleep 1
	fi
done < /tmp/records

/usr/bin/pdnsutil set-kind $DOMAIN MASTER > /dev/null
/usr/bin/pdnsutil set-kind $RDNS.in-addr.arpa MASTER > /dev/null

/usr/bin/pdnsutil rectify-all-zones > /dev/null

/usr/bin/pdns_control notify \* > /dev/null
rm -rf /tmp/yellow

systemctl restart pdns
sleep 2
systemctl restart pdns-recursor
sleep 1

echo "Done"
