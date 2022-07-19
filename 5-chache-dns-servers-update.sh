#!/bin/bash

DATE=`date '+%Y-%m-%d-%H-%M-%S'`

RCONF=/etc/pdns-recursor/recursor.conf

if [ -f "$RCONF" ]; then
	cp ${RCONF} ${RCONF}_${DATE}
	
	while getopts y:b: flag; do
	case $flag in
         y)
          if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
             	#echo "$IP OK"
      	     	YELLOWIP=$OPTARG;
      	  else
          	 echo "Invalid IP Address: $OPTARG, please enter valid YELLOW IP "
           	 exit
      	fi
        ;;

         b)
          if [[ $OPTARG =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                #echo "$IP OK"
                BLUEIP=$OPTARG;
          else
                 echo "Invalid IP Address: $OPTARG, please enter valid BLUE IP "
                 exit
        fi
        ;;

    ?)
      echo -e "usage -y <YELLOW IP> -b <BLUE IP>"
      exit;
      ;;
  esac
done

shift $(( OPTIND - 1 ));

if [ -z "${YELLOWIP}" ] || [ -z "${BLUEIP}" ]; then
     echo -e "usage -y <YELLOW IP> -b <BLUE IP>"
     exit;
fi


ALLOW_FROM=`cat $RCONF | grep ^allow-from= | awk -F= '{ print $2 }'`

	if [[ ! -z "$ALLOW_FROM" ]]; then
		ALLOW_FILE=`cat $RCONF | grep ^allow-from-file= | awk -F= '{ print $2 }'`
		if [[ -f "$ALLOW_FILE" ]]; then
			sed -i '/^allow-from=/d' $RCONF
			IFS=","
			for IP in $ALLOW_FROM
			do
				echo $IP >> $ALLOW_FILE
			done
                        echo $YELLOWIP >> $ALLOW_FILE
                        echo $BLUEIP >> $ALLOW_FILE
                        sort $ALLOW_FILE | uniq > ${ALLOW_FILE}-
                        mv ${ALLOW_FILE}- $ALLOW_FILE
                        systemctl restart pdns-recursor

		else
                        sed -i '/^allow-from=/d' $RCONF
                        IFS=","
                        for IP in $ALLOW_FROM
                        do
                                echo $IP >> /etc/pdns-recursor/recursion-allow-ip-list 
                        done

			echo "allow-from-file=/etc/pdns-recursor/recursion-allow-ip-list" >> $RCONF
			echo $YELLOWIP >> /etc/pdns-recursor/recursion-allow-ip-list
			echo $BLUEIP >> /etc/pdns-recursor/recursion-allow-ip-list
			sort /etc/pdns-recursor/recursion-allow-ip-list | uniq > /etc/pdns-recursor/recursion-allow-ip-list-
			mv /etc/pdns-recursor/recursion-allow-ip-list- /etc/pdns-recursor/recursion-allow-ip-list
			systemctl restart pdns-recursor
			
		fi
	else
		ALLOW_FILE=`cat $RCONF | grep ^allow-from-file= | awk -F= '{ print $2 }'`
		if [[ -f "$ALLOW_FILE" ]]; then
                        echo $YELLOWIP >> $ALLOW_FILE
                        echo $BLUEIP >> $ALLOW_FILE
                        sort $ALLOW_FILE | uniq > ${ALLOW_FILE}-
                        mv ${ALLOW_FILE}- $ALLOW_FILE
                        systemctl restart pdns-recursor
		else
                        echo "allow-from-file=/etc/pdns-recursor/recursion-allow-ip-list" >> $RCONF
                        echo $YELLOWIP >> /etc/pdns-recursor/recursion-allow-ip-list
                        echo $BLUEIP >> /etc/pdns-recursor/recursion-allow-ip-list
                        sort /etc/pdns-recursor/recursion-allow-ip-list | uniq > /etc/pdns-recursor/recursion-allow-ip-list-
                        mv /etc/pdns-recursor/recursion-allow-ip-list- /etc/pdns-recursor/recursion-allow-ip-list
                        systemctl restart pdns-recursor

		fi
	
	fi
	
else
	echo -e "Config file not found: $RCONF"
	exit
fi

