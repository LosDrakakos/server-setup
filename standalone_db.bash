#!/bin/bash
#No Arguments Taken
#PostInstall Script for a Standard Stand-Alone Web Server
#Optimized for Automated Installation of Nginx, PHP5-FPM and MySQL (More comming soon)
#Don't Forget to Fill-in the Declaration Variables
#Feel free to open Issues or to make pull request on my github

#Test if executed as root
export DEBIAN_FRONTEND=noninteractive
if [ "$(id -u)" != "0" ]; then
	echo "Script must be launched as root: # sudo $0" 1>&2
	exit 1
fi
##########################
#----- DECLARATIONS -----#
##########################

dir="$PWD"	#Please don't modify unless you know what you are doing
WHITE="$dir/white.list"	#Please don't modify unless you know what you are doing
hostn="srv.example.com"	#Server Hostname (Please use a FSQN and don't forget to setup your PTR)
CLEF_SSH='KEY1\nKEY2\KEY3' 	#Separate Key with \n
EMAILRECIPIENT='me@example.com, my_colleague@example.com, another_colleague@example.com' #A mail will be sent to theese with the differents passwords generated Followed by the Error Log, there's no email adress limit
MONITRECIPIENT='me@example.com' #Address that will be directly alerted by monit (mmonit notif are independant) PLEASE ONLY USE ONE ADRESS HERE
MONITSERVER="mmonit.example.com" #M/Monit Server FQDN or IP Address
MONITUSER="mmonituser" #Distant M/Monit User
MONITPASSWORD="mmonitpasswd" #Distant M/Monit User Password
SSH_PORT="22" #SSH Listening port, 22 is default, I recommend to change it

#IP you want to bypasss the firewall (please only use static IP you own, could be dangerous otherwise)
#IP Format xxx.xxx.xxx.xxx/xx

cat >> $dir/white.list << EOF
xxx.xxx.xxx.xxx/xx
EOF

##############################
#----- FIN DECLARATIONS -----#
##############################


echo "subject : $hostn Postinstall Report" > $dir/mail
echo"" >> $dir/mail
echo"Install dir : $dir" >> $dir/mail
echo"" >> $dir/mail
#Logging Errors
if [ -s /var/log/PostInstall.log ]
	then
	mv /var/log/PostInstall.log /var/log/PostInstallFIRST.log
	echo "$(tput setaf 1) Script Already Launched Once$(tput sgr0)"
	echo "$(tput setaf 1) Script Already Launched Once...$(tput sgr0)" > /var/log/PostInstall.log
	echo "$(tput setaf 1) Execution will stop, please check  $(tput sgr0)" > /var/log/PostInstall.log
fi
exec 2>>/var/log/PostInstall.log

#Replacing Hostname you'll need to reboot at the end of the script
hostname=$(cat /etc/hostname)
sed -i "s/$hostname/$hostn/g" /etc/hosts
sed -i "s/$hostname/$hostn/g" /etc/hostname

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

apt-get update -y -q

# Upgrade  
apt-get upgrade -y -q

# Firewall Whitelist
	
apt-get install iptables

#Whitelist
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
iptables -t filter -A OUTPUT -p tcp --dport 2812 -j ACCEPT
iptables -t filter -A INPUT -p tcp --sport 2812 -j ACCEPT

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
#Always installed Postfix & Rootkit Hunter & OpenSSL
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections # Postfix Preinstall setup
echo "postfix postfix/mailname string $hostn" | debconf-set-selections
apt-get install rkhunter openssl postfix -y -q
	
#Mysql Passwd gen
openssl rand -base64 12 | sed s/=// >"$dir/mysqlpasswd"
mysqlpasswd=`cat $dir/mysqlpasswd`
echo "mysql-server mysql-server/root_password password $mysqlpasswd" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $mysqlpasswd" | debconf-set-selections

#Install
apt-get install mysql-server -y -q
echo "Mysql user : root"  >> $dir/mail 			echo "Mysql root Password : $mysqlpasswd"  >> $dir/mail
echo ""  >> $dir/mail

#Install Monit
					rm /etc/monit/monitrc
					cat >> /etc/monit/monitrc << EOF
set alert $MONITRECIPIENT
set mail-format {
	from: monit@\$HOST
	subject: \$SERVICE \$EVENT at \$DATE
	message: Monit \$ACTION \$SERVICE at \$DATE on \$HOST: \$DESCRIPTION.
	Yours sincerely,
	monit
	}
set daemon 60           
set logfile /var/log/monit.log
set idfile /var/lib/monit/id
set eventqueue
	basedir /var/lib/monit/events
	slots 100
set mmonit http://$MONITUSER:$MONITPASSWORD@$MONITSERVER:8090/collector
set httpd port 2812
allow localhost
allow $MONITSERVER
allow $MONITUSER:$MONITPASSWORD
include /etc/monit/conf.d/*
check system \$HOST
	if loadavg (5min) > 8 then alert
	if loadavg (15min) > 6 then alert
	if memory usage > 80% for 4 cycles then alert	
	if cpu(system) is greater than 400% for 5 cycles then alert
	if cpu(user) is greater than 400% for 5 cycles then alert
	if cpu(wait) is greater than 400% for 5 cycles then alert
	if cpu(system) is greater than 800% for 5 cycles then alert
    if cpu(user) is greater than 800% for 5 cycles then alert
    if cpu(wait) is greater than 800% for 5 cycles then alert

check process nginx with pidfile /var/run/nginx.pid
	start program = "/etc/init.d/nginx start"
	stop program  = "/etc/init.d/nginx stop"
	group www-data

check process syslogd with pidfile /var/run/rsyslogd.pid
	start program = "/etc/init.d/rsyslog start"
	stop program = "/etc/init.d/rsyslog stop"

check file syslogd_file with path /var/log/syslog
	if timestamp > 65 minutes then alert # Have you seen "-- MARK --"?

check process postfix with pidfile /var/spool/postfix/pid/master.pid
	group mail
	start program = "/etc/init.d/postfix start"
	stop  program = "/etc/init.d/postfix stop"
	if failed port 25 protocol smtp then alert
	depends on postfix_rc

check file postfix_rc with path /etc/init.d/postfix
	group mail
	if failed checksum then unmonitor
	if failed permission 755 then unmonitor
	if failed uid root then unmonitor
	if failed gid root then unmonitor

check process sshd with pidfile /var/run/sshd.pid
	start program  "/etc/init.d/ssh start"
	stop program  "/etc/init.d/ssh stop"
	if failed port $SSH_PORT protocol ssh then alert

EOF
chmod 700 /etc/monit/monitrc
service monit restart

#SSH Setup
	rm /etc/ssh/sshd_config 
	cat >> /etc/ssh/sshd_config  << EOF
		Port $SSH_PORT
		Protocol 2
		HostKey /etc/ssh/ssh_host_rsa_key
		# HostKey /etc/ssh/ssh_host_dsa_key
		HostKey /etc/ssh/ssh_host_ecdsa_key
		HostKey /etc/ssh/ssh_host_ed25519_key
		UsePrivilegeSeparation yes
		KeyRegenerationInterval 3600
		ServerKeyBits 4096
		SyslogFacility AUTH
		LogLevel INFO
		LoginGraceTime 120
		PermitRootLogin yes
		StrictModes yes
		RSAAuthentication yes
		PubkeyAuthentication yes
		AuthorizedKeysFile	%h/.ssh/authorized_keys
		IgnoreRhosts yes
		RhostsRSAAuthentication no
		HostbasedAuthentication no
		PermitEmptyPasswords no
		ChallengeResponseAuthentication no
		PasswordAuthentication no
		X11Forwarding yes
		X11DisplayOffset 10
		PrintMotd no
		PrintLastLog yes
		TCPKeepAlive yes
		AcceptEnv LANG LC_*
		Subsystem sftp /usr/lib/openssh/sftp-server
		UsePAM yes
		
EOF
					
	service ssh restart

#System Cleaning
apt-get autoremove -y -q
apt-get clean -q

ifconfig >> $dir/mail
if [ -s /var/log/PostInstall.log ]
then
	cat /var/log/PostInstall.log 
	cat /var/log/PostInstall.log  >> $dir/mail
	sendmail $EMAILRECIPIENT < $dir/mail
	rm $dir/createdb.sql $dir/mail $dir/mysqlpasswd $dir/utilities.list $dir/white.list $dir/usersftp.list
	export DEBIAN_FRONTEND=dialog
	exit 1
else
echo 'Fin du script sans erreurs \o/' >> /var/log/PostInstall.log
	cat /var/log/PostInstall.log  >> $dir/mail
	sendmail $EMAILRECIPIENT < $dir/mail
	rm $dir/createdb.sql $dir/mail $dir/mysqlpasswd $dir/utilities.list $dir/white.list $dir/usersftp.list
	export DEBIAN_FRONTEND=dialog
	exit 0
