#!/bin/bash

DATE=`date '+%Y-%m-%d-%H-%M-%S'`

CONF=/etc/pdns/pdns.conf
RCONF=/etc/pdns-recursor/recursor.conf

MASTER_LISTEN_IP=`cat $CONF | grep ^local-address= | awk -F= '{ print $2 }'`
PRIMARY_MASTE_IP=`cat $CONF | grep ^allow-notify-from= | awk -F= '{ print $2 }'`
RECURSOR_LISTEN_IP=`cat $RCONF | grep ^local-address= | awk -F= '{ print $2 }' | awk -F, '{ print $2 }'`

DOMAIN=`cat $RCONF | grep ^forward-zones-recurse | awk -F= '{ print $2 }'`

SERVER_TYPE=`cat $CONF | egrep ^primary= | awk -F= '{ print $2}'`

CHECK_DNS() {
	
	for PDNS in {1..3}; do
		RES=`dig +short ns1.$DOMAIN @$MASTER_LISTEN_IP`
		
		if [[ -z "$RES" ]]; then
			systemctl restart pdns
			echo "Error: pdns DNS Record Name resolution failed: Trying $PDNS: dig +short ns1.$DOMAIN @$MASTER_LISTEN_IP" 
			sleep 2
		else
			echo "Ok: pdns DNS Record Name resolution ok: check $PDNS: dig +short ns1.$DOMAIN @$MASTER_LISTEN_IP"
			break
		fi
	done

	for RDNS in {1..3}; do
		RECURSOR=`dig +short ns1.$DOMAIN @$RECURSOR_LISTEN_IP`
		
		if [[ -z "$RECURSOR" ]]; then
			systemctl restart pdns-recursor
			echo "Error: pdns-recursor DNS Record Name resolution failed: Trying $PDNS: dig +short ns1.$DOMAIN @$RECURSOR_LISTEN_IP"
			sleep 2
			
		else
			echo "OK: pdns-recursor DNS Record Name resolution ok: check $RDNS dig +short ns1.$DOMAIN @$RECURSOR_LISTEN_IP"
			break
		fi
	done

}

if [[ "$SERVER_TYPE" = "yes" ]]; then


	for ZONE in `pdnsutil list-all-zones`
	do
		 pdnsutil increase-serial $ZONE
	done

	/usr/bin/pdns_control notify \* > /dev/null
	sleep 2
	CHECK_DNS
fi


if [[ "$SERVER_TYPE" = "no" ]]; then

ZLIST=`pdnsutil list-all-zones`
if [[ -z "$ZLIST" ]]; then
	echo "Error: No zones found in slave server"
	exit
fi


FAILED_ZONES=" "
SUCCESS_ZONES=" "
RET="0"

for ZONE in `/usr/bin/pdnsutil list-all-zones | /usr/bin/grep -v All`
do

echo abc > /tmp/dns1
if test $? -ne 0
then
	echo "Script execution Failed. unable to write /tmp/dns1"
	exit
fi

echo xyz > /tmp/dns2
if test $? -ne 0
then
        echo "Script execution Failed. unable to write /tmp/dns2"
	exit
fi


/usr/bin/dig +nottlid +noall +answer -t AXFR @${PRIMARY_MASTE_IP} ${ZONE} | sort -u > /tmp/dns1
/usr/bin/dig +nottlid +noall +answer -t AXFR @${MASTER_LISTEN_IP} ${ZONE} | sort -u > /tmp/dns2

/usr/bin/diff /tmp/dns1 /tmp/dns2 &> /dev/null 
if test $? -ne 0
then
	FAILED_ZONES="$FAILED_ZONES   $ZONE"
	RET=1
else
	SUCCESS_ZONES="$SUCCESS_ZONES $ZONE"
fi

done

if test $RET -eq 1
then
	echo Failed Zones: $FAILED_ZONES, Success Zones: $SUCCESS_ZONES
else
	echo Success Zones: $SUCCESS_ZONES
fi


CHECK_DNS
fi

