Notes: 
    Recursor feature was removed from pdns server new verstion. 
    Hence small change in DNS architecture.

    PDNS authoritative dns server is runnig on YELLOW VLAN IP
    PDNS recursor is running on BLUE VLAN IP

    Zone transfer between DNS servers will use YELLOW VLAN
    User/Servers will connect BLUE VLAN IP for name resolutoin


1. Build Templete
2. Build DNS VM from Templete
3. run 1-all-nodes-pdns-setup.sh both dns servers
       
     ./1-all-nodes-pdns-setup.sh -f hec.abc.com -c 8.8.8.8 -C 4.4.4.4 -y 172.16.20.20 -b 10.10.20.50
     ./1-all-nodes-pdns-setup.sh -f hec.abc.com -c 8.8.8.8 -C 4.4.4.4 -y 172.16.20.21 -b 10.10.20.51

	-f: HEC FQDN
      -c: Cache DNS 1 IP
	-C: Cache DNS 2 IP
      -g: DNS Server YELLOW VLAN IP
      -b: DNS Server BLUE VLAN IP

4. upload "/tmp/records" to master node to create DNS records

	File Format: csv
	example: short-dns-name,type,content

	mail,A,192.168.1.2
	web,A,192.168.1.3
      app,CNAME,app1.cloud4c.com

	Here only two type records are valid: A or CNAME
		A for IP Address
		CNAME for FQDN

5. run master script in master node

./2-master-pdns-master.sh -f hec.abc.com -m 172.16.20.20 -s 172.16.20.21
	-f: HEC FQDN
	-m: YELLOW VLAN MASTER DNS IP
	-s: YELLOW VLAN SLAVE DNS IP

6. run slave script in slave node

./3-slave-pdns-slave.sh -f hec.abc.com -m 172.16.20.20
	-f: HEC FQDN
	-m: YELLOW VLAN MASTER DNS IP

7. check the dns servers

	./4-all-nodes-checks.sh
	
	Note: Execute this script master node first and later run on slave node.

8. allow new cidr in cache dns servers

	./5-chache-dns-servers-update.sh -y 172.16.20.20 -b 10.10.20.50

	-y YELLOW VLAN IP
	-b BLUE VLAN IP


