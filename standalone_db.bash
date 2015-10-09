#!/bin/bash
#No Arguments Taken
#PostInstall Script for a Standard Stand-Alone Web Server
#Optimized for Automated Installation of Nginx, PHP5-FPM and MySQL (More comming soon)
#Don't Forget to Fill-in the Declaration Variables
#Feel free to open Issues or to make pull request on my github

#Test if executed as root

	if [ "$(id -u)" != "0" ]; then
		echo "Script must be launched as root: # sudo $0" 1>&2
		exit 1
	fi
##########################
#----- DECLARATIONS -----#
##########################

	dir="$PWD"	#Please don't modify unless you know what you are doing
	WHITE="$dir/white.list"	#Please don't modify unless you know what you are doing
	hostn="db.example.com"	#Server Hostname (Please use a FSQN and don't forget to setup your PTR)
	CLEF_SSH='KEY1\nKEY2\KEY3' 	#Separate Key with \n
	EMAILRECIPIENT='me@example.com, my_colleague@example.com, another_colleague@example.com' #A mail will be sent to theese with the differents passwords generated Followed by the Error Log, there's no email adress limit
	MONITSERVER="mmonit.example.com" #M/Monit Server FQDN or IP Address
	MONITUSER="mmonituser" #Distant M/Monit User
	MONITPASSWORD="mmonitpasswd" #Distant M/Monit User Password
	SSH_PORT="22" #SSH Listening port, 22 is default, I recommend to change it

#IP you want to bypasss the firewall (please only use static IP you own, could be dangerous otherwise)
#IP Format xxx.xxx.xxx.xxx/xx

cat >> $dir/white.list << EOF
xxx.xxx.xxx.xxx/xx
xxx.xxx.xxx.xxx/xx
EOF

##############################
#----- FIN DECLARATIONS -----#
##############################


	echo "subject : $hostn Postinstall Report (Standalone Database" > $dir/mail

#Replacing Hostname you'll need to reboot at the end of the script
	hostname=$(cat /etc/hostname)
	sed -i "s/$hostname/$hostn/g" /etc/hosts
	sed -i "s/$hostname/$hostn/g" /etc/hostname

#Logging Errors
	if [ -s /var/log/PostInstall.log ]
		then
		rm /var/log/PostInstall.log
		echo "$(tput setaf 1) ATTENTION LE SCRIPT AVAIT DEJA ETE LANCE$(tput sgr0)"
	fi
	exec 2>>/var/log/PostInstall.log

# SSH Key ADD
	mkdir -p /root/.ssh/
	echo -e "$CLEF_SSH" >> /root/.ssh/authorized_keys

# Locking root Password Login
	passwd root -l

# Update&Upgrade
#Sometimes there's issues with Digital Oceans Repo
#Fell free to uncomment to use thoose instead (or just use any other repo you want
#cat > /etc/apt/sources.list << EOF
#deb http://fr.archive.ubuntu.com/ubuntu/ trusty main restricted universe multiverse 
#deb http://fr.archive.ubuntu.com/ubuntu/ trusty-security main restricted universe multiverse 
#deb http://fr.archive.ubuntu.com/ubuntu/ trusty-updates main restricted universe multiverse 
#EOF

	apt-get update -y

# Upgrade  
	apt-get upgrade -y

# Firewall Whitelist
	
	iptables -F
	iptables -t filter -P OUTPUT DROP
	iptables -t filter -P INPUT DROP
	
	iptables -t filter -A INPUT -i lo -j ACCEPT
	iptables -t filter -A OUTPUT -o lo -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 21 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
	iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
	iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
			
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

for ipok in $(cat $WHITE)
	do
	iptables -A INPUT -s $ipok -j ACCEPT
	iptables -A OUTPUT -d $ipok -j ACCEPT
done

	iptables-save > /root/iptablesbkp
	
	echo "/sbin/iptables-restore < /root/iptablesbkp" >> /etc/rc.local

#Paquets installation
	#Always installed Postfix & Rootkit Hunter
	echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections # Postfix Preinstall setup
	echo "postfix postfix/mailname string $hostn" | debconf-set-selections
	apt-get install rkhunter postfix -y
	
##TODO : Add Mysql COnfig
