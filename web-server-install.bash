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
	branch="master" #Git branch to use. Please don't modify unless you know what you are doing
	dir="$PWD"	#Please don't modify unless you know what you are doing
	UTILS="$dir/utilities.list"	#Please don't modify unless you know what you are doing
	WHITE="$dir/white.list"	#Please don't modify unless you know what you are doing
	USERSFTP="$dir/usersftp.list" #Please don't modify unless you know what you are doing
	hostn="srv.example.com"	#Server Hostname (Please use a FSQN and don't forget to setup your PTR)
	ISVZ="False" # Set to 'True' if the system is in container and does not have its own Kernel (Like OpenVZ)
	CLEF_SSH='KEY1\nKEY2\KEY3' 	#Separate Key with \n
	EMAILRECIPIENT='me@example.com, my_colleague@example.com, another_colleague@example.com' #A mail will be sent to theese with the differents passwords generated Followed by the Error Log, there's no email adress limit
	MONITRECIPIENT='me@example.com' #Address that will be directly alerted by monit (mmonit notif are independant) PLEASE ONLY USE ONE ADRESS HERE
	MONITSERVER="mmonit.example.com" #M/Monit Server FQDN or IP Address
	MONITUSER="mmonituser" #Distant M/Monit User
	MONITPASSWORD="mmonitpasswd" #Distant M/Monit User Password
	SSH_PORT="22" #SSH Listening port, 22 is default, I strongly recommend to change it
	PRESTASHOPFQDN="prestashop.example.com" #The FQDN pointing to your web site (be sure to setup your ZoneDNS or HOSTS file accordingly)
	PRESTADIR="/home/www/prestashop/www" # Absolute Path for your prestashop webdir
	LARAVELFQDN="laravel.example.com" #The FQDN pointing to your web site (be sure to setup your ZoneDNS or HOSTS file accordingly)
	LARAVELDIR="/home/www/laravel" # Absolute Path for your laravel clean install. As the web accessible file is $LARAVELDIR/public, i don't sense the nececity of adding an extra www folder, like for prestashop

#GET du Utilities depuis le NAS (Don't mind this comment)
#Si pas de NAS (Don't mind this comment)
#Package You want to install
#The default list should be enough
#But feel free to add others
#Please keep in mind that if you add your own packages
#that prompts could show up, and you could need human intervention for the script to end
# Package currently fully-supported : mysql-server, nginx, php5-fpm, php5-mcrypt, monit, pure-ftpd-mysql, laravel, prestashop1.6
#Please Always put mysql-server first

cat >> $dir/utilities.list << EOF
mysql-server
nginx
php5-fpm
php5-imagick
php5-gd
php5-mcrypt
php5-mysql
monit
pure-ftpd-mysql
EOF

#Fin Si pas de NAS (Don't mind this comment)

#GET WhiteList depuis le NAS (Don't mind this comment)
#Si pas de NAS (Don't mind this comment)
#IP you want to bypasss the firewall (please only use static IP you own, could be dangerous otherwise)
#IP Format xxx.xxx.xxx.xxx/xx

cat >> $dir/white.list << EOF
X.X.X.X.X/XX
X.X.X.X.X/XX
EOF

#Fin Si pas de NAS (Don't mind this comment)

#GET FTPUserList depuis le NAS (Don't mind this comment)
#Si pas de NAS (Don't mind this comment)
#FTPUserTo create Automatically
#Syntax is username:/home/directory:password
#If you want a randomly generated password just type 'random' in the password field
#In the example below, username1's password will be 'username1password'
#but username2's passxord will be randomly generated
cat >> $dir/usersftp.list << EOF
username1:/home/username1:username1password
username2:/home/username2:random
EOF
#Fin Si pas de NAS (Don't mind this comment)

##############################
#----- FIN DECLARATIONS -----#
##############################

	echo "subject : $hostn Postinstall Report" > $dir/mail

#Replacing Hostname you'll need to reboot at the end of the script
	sed -i "s/$HOSTNAME/$hostn/g" /etc/hosts
	sed -i "s/$HOSTNAME/$hostn/g" /etc/hostname
	hostname $hostn

#Logging Errors
	if [ -s /var/log/postinstall.log ]
		then
		rm /var/log/postinstall.log
		echo "$(tput setaf 1) ATTENTION LE SCRIPT AVAIT DEJA ETE LANCE$(tput sgr0)"
	fi
	exec 2>>/var/log/postinstall.log

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

	apt-get install iptables -y -q

	#Whitelist
	iptables -F
	iptables -t filter -P OUTPUT DROP
	iptables -t filter -P INPUT DROP

	for ipok in $(cat $WHITE)
		do
		iptables -A INPUT -s "$ipok" -j ACCEPT
		iptables -A OUTPUT -d "$ipok" -j ACCEPT
	done

	iptables -t filter -A INPUT -i lo -j ACCEPT
	iptables -t filter -A OUTPUT -o lo -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 21 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
	iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
	iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
	#iptables -t filter -A OUTPUT -p tcp --dport 2812 -j ACCEPT #Commented until further notice
	iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
	iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
	iptables -t filter -A INPUT -p tcp --dport 21 -j ACCEPT
	#iptables -t filter -A INPUT -p tcp --sport 2812 -j ACCEPT #Commented until further notice

	iptables -A INPUT -i eth0 -p icmp -j ACCEPT

	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	if [ "$ISVZ" = "False" ]; then
		exec 2>>/var/log/Build.log #Special Error Log for xtable If any error while enabling Iptable GEOIP rules, check this log.
		apt-get install iptables iptables-dev module-assistant xtables-addons-common libtext-csv-xs-perl unzip build-essential -y -q
		module-assistant auto-install xtables-addons -i -q -n

		cd /usr/lib/xtables-addons/
		sed -i "s/wget/wget -q/g" /usr/lib/xtables-addons/xt_geoip_dl
		sed -i "s/unzip/unzip -q/g" /usr/lib/xtables-addons/xt_geoip_dl
		sed -i "s/gzip/gzip -q/g" /usr/lib/xtables-addons/xt_geoip_dl
		./xt_geoip_dl
		./xt_geoip_build GeoIPCountryWhois.csv
		mkdir -p /usr/share/xt_geoip/
		cp -r {BE,LE} /usr/share/xt_geoip/
		exec 2>>/var/log/postinstall.log #Back to normal Log
		iptables -A INPUT -m geoip --source-country RU,CN,UA,TW,TR,SK,RO,PL,CZ,BG  -j DROP #Blocking potential botnet zone (No offense intended if you live here, but it's my client policy...)

	fi

	iptables-save > /root/iptablesbkp

	rm /etc/rc.local
	echo "/sbin/iptables-restore < /root/iptablesbkp" >> /etc/rc.local
	echo "exit 0" >> /etc/rc.local

#Paquets installation
	#Always installed Postfix & Rootkit Hunter
	echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections # Postfix Preinstall setup
	echo "postfix postfix/mailname string $hostn" | debconf-set-selections
	apt-get install rkhunter postfix openssl -y -q
		echo "" >> $dir/mail
		echo "Paquets installés" >> $dir/mail
		echo "" >> $dir/mail
		for paquet in $(cat $UTILS)
		do
			echo "$paquet" >> $dir/mail

			#MYSQL PreInstall & Install

			if [ "$paquet" = "mysql-server" ]
			then
					#Mysql Passwd gen
					openssl rand -base64 12 | sed 's/\/=//g' > $dir/mysqlpasswd
					mysqlpasswd=$(cat "$dir/mysqlpasswd")
					echo "mysql-server mysql-server/root_password password $mysqlpasswd" | debconf-set-selections
					echo "mysql-server mysql-server/root_password_again password $mysqlpasswd" | debconf-set-selections
					#Install
					apt-get install mysql-server -y -q

				echo "Mysql user : root"  >> $dir/mail
				echo "Mysql root Password : $mysqlpasswd"  >> $dir/mail
				echo ""  >> $dir/mail
			#----------------------------------#
			#------------prestashop------------#
			#----------------------------------#
			elif [ "$paquet" = "prestashop1.6" ]
			then
			webserver=false

					#If webserver nginx
					if [ -d /etc/nginx ]
						then
						webserver=true
						apt-get install zip php5-imagick php5-gd php5-mysql -q -y

						if [ -s /etc/php5/mods-available/mcrypt.ini  ]; then
							if [ -s /etc/php5/mods-enabled/mcrypt.ini ]; then
								echo "mcrypt already enabled"
							else
								php5enmod mcrypt
								echo "mcrypt enabled by Prestashop" >> $dir/mail
								echo "" >> $dir/mail
							fi
						elif [ -s /etc/php5/conf.d/mcrypt.ini ]; then
							ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available/mcrypt.ini
							php5enmod mcrypt
							echo "mcrypt symlinked & enabled by Prestashop" >> $dir/mail
							echo "" >> $dir/mail
						else
							apt-get install -y -q php5-mcrypt
							ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available/mcrypt.ini
							php5enmod mcrypt
							echo "mcrypt installed & symlinked & enabled by Prestashop" >> $dir/mail
							echo "" >> $dir/mail
						fi

						mkdir -p $PRESTADIR
						cd $PRESTADIR
						wget -q https://www.prestashop.com/download/old/prestashop_1.6.1.0.zip
						unzip -q prestashop*.zip
						mv prestashop/* ./
						cd $dir
						chown 33:33 -R $PRESTADIR
						chmod 755 -R $PRESTADIR
						# Prestashop mysql user creation
						openssl rand -base64 12 > $dir/prestapasswd
						prestapasswd=$(cat $dir/prestapasswd)

						cat > $dir/createdbpresta.sql << EOF

#Creating Database for pure-ftpd-mysql
#With user 'pureftpd', the password is randomly generated
CREATE DATABASE prestashop;
CREATE USER 'prestashop'@'localhost' IDENTIFIED BY '$prestapasswd';
GRANT all ON prestashop.* TO 'prestashop'@'localhost';
FLUSH PRIVILEGES;
EOF

						mysql -u root -p$mysqlpasswd < $dir/createdbpresta.sql
						echo "Mysql user for Prestashop : prestashop" >> $dir/mail
						echo "Mysql Password for Prestashop : $prestapasswd"  >> $dir/mail
						echo "" >> $dir/mail

cat >> /etc/nginx/sites-available/$PRESTASHOPFQDN.serverblock << EOF
server {
	server_name $PRESTASHOPFQDN;
	root $PRESTADIR;
	index index.php;
	listen 0.0.0.0:80;

 	fastcgi_param  PHP_ADMIN_VALUE "open_basedir=$PRESTADIR";
	access_log /var/log/80-access-$PRESTASHOPFQDN combined;
	error_log /var/log/80-error-$PRESTASHOPFQDN warn;
	log_not_found off;
	expires max;
	if_modified_since before;
	client_body_buffer_size 1M;
	client_header_buffer_size 1M;
	client_max_body_size 3M;
	large_client_header_buffers 1 2M;
	client_body_timeout 10;
	client_header_timeout 10;
	keepalive_timeout 15;
	send_timeout 5;
	fastcgi_buffers 256 256k;
	fastcgi_buffer_size 512k;

	location = /robots.txt  { access_log off; log_not_found off; expires 30d; }
	location = /favicon.ico { access_log off; log_not_found off; expires 30d; }
	location / {
		rewrite ^/api/?(.*)$ /webservice/dispatcher.php?url=\$1 last;
		rewrite ^/([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$1\$2.jpg last;
		rewrite ^/([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$1\$2\$3.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$1\$2\$3\$4.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$1\$2\$3\$4\$5.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$1\$2\$3\$4\$5\$6.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$1\$2\$3\$4\$5\$6\$7.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$7/\$1\$2\$3\$4\$5\$6\$7\$8.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$7/\$8/\$1\$2\$3\$4\$5\$6\$7\$8\$9.jpg last;
		rewrite ^/c/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\\.jpg$ /img/c/\$1\$2.jpg last;
		rewrite ^/c/([a-zA-Z-]+)(-[0-9]+)?/.+\\.jpg$ /img/c/\$1.jpg last;
		rewrite ^/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\\.jpg$ /img/c/\$1\$2.jpg last;
		try_files \$uri \$uri/ /index.php?\$args;
	}
	location ~ \\.php$ {
		fastcgi_pass unix:/var/run/php5-fpm.sock;
		fastcgi_split_path_info ^(.+\\.php)(/.\*)$;
		include /etc/nginx/fastcgi_params;
	}
	location ~ /\\. {
		deny  all;
		access_log  off;
		log_not_found  off;
	}

}
server {
	server_name $PRESTASHOPFQDN;
	root $PRESTADIR;
	index index.php;
	listen 0.0.0.0:443;
#	ssl    on;
#	ssl_certificate PATH_TO_CRT;
#	ssl_certificate_key PATH_TO_key;
#	ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";
#	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
#	ssl_prefer_server_ciphers on;
#	ssl_session_cache shared:SSL:10m;

 	fastcgi_param  PHP_ADMIN_VALUE "open_basedir=$PRESTADIR";
	access_log /var/log/443-access-$PRESTASHOPFQDN combined;
	error_log /var/log/443-error-$PRESTASHOPFQDN warn;
	log_not_found off;
	expires max;
	if_modified_since before;
	client_body_buffer_size 1M;
	client_header_buffer_size 1M;
	client_max_body_size 3M;
	large_client_header_buffers 1 2M;
	client_body_timeout 10;
	client_header_timeout 10;
	keepalive_timeout 15;
	send_timeout 5;
	fastcgi_buffers 256 256k;
	fastcgi_buffer_size 512k;

	location = /robots.txt  { access_log off; log_not_found off; expires 30d; }
	location = /favicon.ico { access_log off; log_not_found off; expires 30d; }
	location / {
		rewrite ^/api/?(.*)$ /webservice/dispatcher.php?url=\$1 last;
		rewrite ^/([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$1\$2.jpg last;
		rewrite ^/([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$1\$2\$3.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$1\$2\$3\$4.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$1\$2\$3\$4\$5.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$1\$2\$3\$4\$5\$6.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$1\$2\$3\$4\$5\$6\$7.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$7/\$1\$2\$3\$4\$5\$6\$7\$8.jpg last;
		rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\\.jpg$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$7/\$8/\$1\$2\$3\$4\$5\$6\$7\$8\$9.jpg last;
		rewrite ^/c/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\\.jpg$ /img/c/\$1\$2.jpg last;
		rewrite ^/c/([a-zA-Z-]+)(-[0-9]+)?/.+\\.jpg$ /img/c/\$1.jpg last;
		rewrite ^/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\\.jpg$ /img/c/\$1\$2.jpg last;
		try_files \$uri \$uri/ /index.php?\$args;
	}
	location ~ \\.php$ {
		fastcgi_pass unix:/var/run/php5-fpm.sock;
		fastcgi_split_path_info ^(.+\\.php)(/.\*)$;
		include /etc/nginx/fastcgi_params;
	}
	location ~ /\\. {
		deny  all;
		access_log  off;
		log_not_found  off;
	}

}

EOF
							ln -s /etc/nginx/sites-available/$PRESTASHOPFQDN.serverblock /etc/nginx/sites-enabled/$PRESTASHOPFQDN.serverblock
							if [ -s /etc/nginx/sites-enabled/default ]; then
								rm /etc/nginx/sites-enabled/default
							fi

							service nginx restart

						elif [ -d /etc/apache2 ]
						then
							echo "APACHE VHOST not supported yet" >> $dir/mail
							webserver=true
						fi



				if [ "$webserver" = "false" ]
					then
					echo "Please Install a webserver in order to install Prestashop" >> $dir/mail
					echo "" >> $dir/mail
				fi
			#----------------------------------#
			#--------fin-prestashop------------#
			#----------------------------------#
			#----------------------------------#
			#--------------COMPOSER------------#
			#----------------------------------#
			elif [ "$paquet" = "composer" ]
				then

				if [ -s /usr/local/bin/composer ]
				then
					echo "Composer already installed by another package" >> $dir/mail
					echo "" >> $dir/mail
				else
					apt-get install curl php5-cli -y -q
					curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
				fi

			#----------------------------------#
			#---------------LARAVEL------------#
			#----------------------------------#
			elif [ "$paquet" = "laravel" ]
				then
				webserver=false
					if [ -d /etc/nginx ] #If webserver is nginx
					then
						webserver=true

						mkdir -p $LARAVELDIR
						chown 33:33 -R $LARAVELDIR
						chmod 755 -R $LARAVELDIR
						# laravel mysql user creation
						openssl rand -base64 12 > $dir/laravelpasswd
						laravelpasswd=$(cat $dir/laravelpasswd)

						cat > $dir/createdblaravel.sql << EOF

CREATE DATABASE laravel;
CREATE USER 'laravel'@'localhost' IDENTIFIED BY '$laravelpasswd';
GRANT all ON laravel.* TO 'laravel'@'localhost';
FLUSH PRIVILEGES;
EOF
						mysql -u root -p$mysqlpasswd < $dir/createdblaravel.sql
						echo "Mysql user for laravel : laravel" >> $dir/mail
						echo "Mysql Password for laravel : $laravelpasswd"  >> $dir/mail
						echo "" >> $dir/mail

cat >> /etc/nginx/sites-available/$LARAVELFQDN.serverblock << EOF
server {
server_name $LARAVELFQDN;
root $LARAVELDIR;
index index.php;
listen 0.0.0.0;
#	ssl    on;
#	ssl_certificate PATH_TO_CRT;
#	ssl_certificate_key PATH_TO_key;
#	ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:ECDHE-RSA-AES128-GCM-SHA256:AES256+EECDH:DHE-RSA-AES128-GCM-SHA256:AES256+EDH:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";
#	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
#	ssl_prefer_server_ciphers on;
#	ssl_session_cache shared:SSL:10m;

fastcgi_param  PHP_ADMIN_VALUE "open_basedir=$LARAVELDIR";
access_log /var/log/access-$LARAVELFQDN combined;
error_log /var/log/error-$LARAVELFQDN warn;
log_not_found off;
expires max;
if_modified_since before;
client_body_buffer_size 1M;
client_header_buffer_size 1M;
client_max_body_size 3M;
large_client_header_buffers 1 2M;
client_body_timeout 10;
client_header_timeout 10;
keepalive_timeout 15;
send_timeout 5;
fastcgi_buffers 256 256k;
fastcgi_buffer_size 512k;

location / {
	try_files \$uri \$uri/ /index.php?\$args;
}
location ~ \\.php$ {
	try_files \$uri /index.php =404;
	fastcgi_index index.php;
	fastcgi_pass unix:/var/run/php5-fpm.sock;
	fastcgi_split_path_info ^(.+\\.php)(/.+)$;
	include /etc/nginx/fastcgi_params;
}
location ~ /\\. {
	deny  all;
	access_log  off;
	log_not_found  off;
}

}

EOF
							ln -s /etc/nginx/sites-available/$LARAVELFQDN.serverblock /etc/nginx/sites-enabled/$LARAVELFQDN.serverblock
							if [ -s /etc/nginx/sites-enabled/default ]; then
								rm /etc/nginx/sites-enabled/default
							fi

							service nginx restart

						elif [ -d /etc/apache2 ] #if web server is Apache2
							then
							echo "APACHE VHOST not supported yet" >> $dir/mail
							webserver=true
						fi

					if [ "$webserver" = "false" ] # if nor Nginx nor Apache2
						then
						echo "Please Install a webserver in order to use laravel" >> $dir/mail
						echo "Although it was installed as asked" >> $dir/mail
						echo "" >> $dir/mail
					fi
					if [ -s /etc/php5/mods-available/mcrypt.ini  ]; then
						if [ -s /etc/php5/mods-enabled/mcrypt.ini ]; then
							echo "mcrypt already enabled"
						else
							php5enmod mcrypt
							echo "mcrypt enabled by Laravel" >> $dir/mail
							echo "" >> $dir/mail
						fi
					elif [ -s /etc/php5/conf.d/mcrypt.ini ]; then
						ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available/mcrypt.ini
						php5enmod mcrypt
						echo "mcrypt symlinked & enabled by Laravel" >> $dir/mail
						echo "" >> $dir/mail
					else
						apt-get install -y -q php5-mcrypt
						ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available/mcrypt.ini
						php5enmod mcrypt
						echo "mcrypt installed & symlinked & enabled by Laravel" >> $dir/mail
						echo "" >> $dir/mail
					fi
					service php5-fpm restart
					if [ -s /usr/local/bin/composer ]
					then
						composer create-project laravel/laravel $LARAVELDIR "~5.0.0" --prefer-dist -q
					else
						apt-get install curl php5-cli -y -q
						curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer
						composer create-project laravel/laravel $LARAVELDIR "~5.0.0" --prefer-dist -q
						echo "Composer was needed by $paquet, so it was installed" >> $dir/mail
						echo "" >> $dir/mail
					fi
					chown 33:33 -R $LARAVELDIR
					chmod 755 -R $LARAVELDIR

			else
				#----------------------------------#
				#---------------AUTRE--------------#
				#----------------------------------#
				apt-get install $paquet -y -q
			fi
		done
	echo "" >> $dir/mail
#Paquets SetUp
	for paquet in $(cat "$UTILS")
		do
			case "$paquet" in

				"php5-fpm")


					# PHP5-FPM Setup

					rm /etc/php5/fpm/php.ini
					cat >> /etc/php5/fpm/php.ini << EOF

[PHP]
engine = On
short_open_tag = Off
asp_tags = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
unserialize_callback_func =
serialize_precision = 17
disable_functions = pcntl_alarm,pcntl_fork,pcntl_waitpid,pcntl_wait,pcntl_wifexited,pcntl_wifstopped,pcntl_wifsignaled,pcntl_wexitstatus,pcntl_wtermsig,pcntl_wstopsig,pcntl_signal,pcntl_signal_dispatch,pcntl_get_last_error,pcntl_strerror,pcntl_sigprocmask,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_exec,pcntl_getpriority,pcntl_setpriority,
zend.enable_gc = On
expose_php = Off
max_execution_time = 60
max_input_time = 60
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
track_errors = Off
html_errors = On
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 20M
default_mimetype = "text/html"
default_charset = "UTF-8"
enable_dl = Off
cgi.fix_pathinfo=0
file_uploads = On
upload_max_filesize = 20M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 90
[CLI Server]
cli_server.color = On
[Date]
date.timezone = Europe/Paris
[Pdo_mysql]
pdo_mysql.cache_size = 2000
pdo_mysql.default_socket=
[mail function]
SMTP = localhost
smtp_port = 25
mail.add_x_header = Off
[ODBC]
odbc.allow_persistent = On
odbc.check_persistent = On
odbc.max_persistent = -1
odbc.max_links = -1
odbc.defaultlrl = 4096
odbc.defaultbinmode = 1
[Interbase]
ibase.allow_persistent = 1
ibase.max_persistent = -1
ibase.max_links = -1
ibase.timestampformat = "%Y-%m-%d %H:%M:%S"
ibase.dateformat = "%Y-%m-%d"
ibase.timeformat = "%H:%M:%S"
[MySQL]
mysql.allow_local_infile = On
mysql.allow_persistent = On
mysql.cache_size = 2000
mysql.max_persistent = -1
mysql.max_links = -1
mysql.connect_timeout = 60
mysql.trace_mode = Off
[Sybase-CT]
sybct.allow_persistent = On
sybct.max_persistent = -1
sybct.max_links = -1
sybct.min_server_severity = 10
sybct.min_client_severity = 10
[bcmath]
bcmath.scale = 0
[Session]
session.save_handler = files
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
languages such as JavaScript.
session.serialize_handler = php
session.gc_probability = 0
session.gc_divisor = 1000
session.gc_maxlifetime = 1440
session.bug_compat_42 = Off
session.bug_compat_warn = Off
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.hash_function = 0
session.hash_bits_per_character = 5
url_rewriter.tags = "a=href,area=href,frame=src,input=src,form=fakeentry"
[Tidy]
tidy.clean_output = Off
[soap]
soap.wsdl_cache_enabled=1
soap.wsdl_cache_dir="/tmp"
soap.wsdl_cache_ttl=86400
soap.wsdl_cache_limit = 5
[opcache]
opcache.enable=1
opcache.memory_consumption=512
opcache.interned_strings_buffer=4
opcache.max_accelerated_files=5000
opcache.use_cwd=1
opcache.validate_timestamps=1
opcache.revalidate_freq=60
opcache.save_comments=0
opcache.load_comments=0
opcache.fast_shutdown=1

EOF

service php5-fpm restart

					;;

				"php5-mcrypt")
						if [ -s /etc/php5/mods-available/mcrypt.ini  ]; then
							if [ -s /etc/php5/mods-enabled/mcrypt.ini ]; then
								echo "mcrypt already enabled"
							else
								php5enmod mcrypt
							fi
						else
							ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available/mcrypt.ini
							php5enmod mcrypt
						fi
						service php5-fpm restart

					;;

			"nginx")

				# Nginx Setup
					rm /etc/nginx/nginx.conf
					cat >> /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes 4;
pid /run/nginx.pid;

events {
	worker_connections 768;
}
http {

	sendfile on;
	tcp_nopush on;
	tcp_nodelay on;
	keepalive_timeout 65;
	types_hash_max_size 2048;
	include /etc/nginx/mime.types;
	default_type application/octet-stream;
	access_log /var/log/nginx/access.log;
	error_log /var/log/nginx/error.log;
	gzip on;
	gzip_disable "msie6";
	fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=nginxcache:10m inactive=1h max_size=1g;
	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}

EOF
				cat >> serverblock.example << EOF

server {
    server_name www.example.com;
    root /example/directory/;
    index index.html index.php;

    location ~ \\.php$
    {
        fastcgi_pass unix:/var/run/php5-fpm.sock;
        fastcgi_split_path_info ^(.+\\.php)(/.*)$;
        include /etc/nginx/fastcgi_params;
        #fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}

EOF

				service nginx restart

				;;

				"monit")

					# Monit Setup

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

check process mysql with pidfile /var/run/mysqld/mysqld.pid
	group database
	start program = "/etc/init.d/mysql start"
	stop program = "/etc/init.d/mysql stop"
	if failed host 127.0.0.1 port 3306 protocol mysql then alert

check process sshd with pidfile /var/run/sshd.pid
	start program  "/etc/init.d/ssh start"
	stop program  "/etc/init.d/ssh stop"
	if failed port $SSH_PORT protocol ssh then alert
EOF
chmod 700 /etc/monit/monitrc
service monit restart
			;;
				"pure-ftpd-mysql")

					# Pureftpd-mysql Setup

					openssl rand -base64 12 > $dir/pureftpdpasswd
					ftpdpasswd=$(cat $dir/pureftpdpasswd)

					cat > $dir/createdb.sql << EOF

#Creating Database for pure-ftpd-mysql
#With user 'pureftpd', the password is randomly generated
CREATE DATABASE pureftpd;
USE pureftpd;
CREATE TABLE ftpd ( User varchar(16) NOT NULL default '', status enum('0','1') NOT NULL default '0', Password varchar(64) NOT NULL default '', Uid varchar(11) NOT NULL default '-1', Gid varchar(11) NOT NULL default '-1', Dir varchar(128) NOT NULL default '', ULBandwidth smallint(5) NOT NULL default '0', DLBandwidth smallint(5) NOT NULL default '0', comment tinytext NOT NULL, ipaccess varchar(15) NOT NULL default '*', QuotaSize smallint(5) NOT NULL default '0', QuotaFiles int(11) NOT NULL default 0, PRIMARY KEY (User), UNIQUE KEY User (User));
CREATE USER 'pureftpd'@'localhost' IDENTIFIED BY '$ftpdpasswd';
GRANT all ON pureftpd.* TO 'pureftpd'@'localhost';
FLUSH PRIVILEGES;
EOF

					mysql -u root -p$mysqlpasswd < $dir/createdb.sql

					echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
					echo "/etc/pure-ftpd/db/mysql.conf" > /etc/pure-ftpd/conf/MySQLConfigFile
					echo "yes" > /etc/pure-ftpd/conf/CreateHomeDir
					echo "yes" > /etc/pure-ftpd/conf/ChrootEveryone
					echo "yes" > /etc/pure-ftpd/conf/DontResolve
					echo "32" > /etc/pure-ftpd/conf/MinUID
					echo "no" > /etc/pure-ftpd/conf/UnixAuthentication
					echo "yes" > /etc/pure-ftpd/conf/DisplayDotFiles
					echo "yes" > /etc/pure-ftpd/conf/VerboseLog

					cat > /etc/pure-ftpd/db/mysql.conf << EOF

MYSQLSocket      /var/run/mysqld/mysqld.sock
MYSQLServer     localhost
MYSQLPort       3306
MYSQLUser       pureftpd
MYSQLPassword   $ftpdpasswd
MYSQLDatabase   pureftpd
MYSQLCrypt      md5
MYSQLGetPW      SELECT Password FROM ftpd WHERE User="\\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MYSQLGetUID     SELECT Uid FROM ftpd WHERE User="\\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MYSQLGetGID     SELECT Gid FROM ftpd WHERE User="\\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MYSQLGetDir     SELECT Dir FROM ftpd WHERE User="\\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MySQLGetBandwidthUL SELECT ULBandwidth FROM ftpd WHERE User="\\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MySQLGetBandwidthDL SELECT DLBandwidth FROM ftpd WHERE User="\\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MySQLGetQTASZ   SELECT QuotaSize FROM ftpd WHERE User="\\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
MySQLGetQTAFS   SELECT QuotaFiles FROM ftpd WHERE User="\\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\\R")
EOF

					/etc/init.d/pure-ftpd-mysql restart
					if [ -s $dir/scripts/insertftpduser.bash ]
						then
							cp $dir/scripts/insertftpduser.bash
					elif [ -s $dir/insertftpduser.bash ]
						then
							mkdir -p $dir/scripts
							mv $dir/insertftpduser.bash $dir/scripts/insertftpduser.bash
					else
						mkdir -p $dir/scripts
						cd $dir/scripts
						wget -q https://raw.githubusercontent.com/cthulhuely/server-setup/$branch/scripts/insertftpduser.bash #Get ftp users creation script from my github
						cd $dir
					fi


					echo "Mysql user for Pureftpd : pureftpd" >> $dir/mail
					echo "Mysql Password for Pureftpd : $ftpdpasswd"  >> $dir/mail
					#Creating FTP Users Defined in Declarations
					for ftpuser in $(cat $USERSFTP)
						do

						user=$(echo "$ftpuser" | cut -d ":" -f1)
					userdir=$(echo "$ftpuser" | cut -d ":" -f2)
						userpasswd=$(echo "$ftpuser" | cut -d ":" -f3)
						if [ "$userpasswd" == "random" ]
							then
							openssl rand -base64 12 > $dir/userpasswd
							userpasswd=$(cat $dir/userpasswd)
						fi
						bash $dir/scripts/insertftpduser.bash $user $userdir $userpasswd
						echo "Pureftpd user : $user" >> $dir/mail
						echo "$user homedir : $userdir" >> $dir/mail
						echo "$user ftp password : $userpasswd" >> $dir/mail
						echo "" >> $dir/mail
					done
				;;

			esac

		done
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
	#Deleting parasite lines from the error log
	sed -i '/Extracting templates from packages: [0-9]+*/d' /var/log/postinstall.log
	if [ -s /var/log/postinstall.log ]
	then
		cat /var/log/postinstall.log
		cat /var/log/postinstall.log  >> $dir/mail
		sendmail $EMAILRECIPIENT < $dir/mail
		rm $dir/createdb.sql $dir/mail $dir/mysqlpasswd $dir/utilities.list $dir/white.list $dir/usersftp.list
		export DEBIAN_FRONTEND=dialog
		exit 1
	else
		echo 'Fin du script sans erreurs \o/' >> /var/log/postinstall.log
		cat /var/log/postinstall.log  >> $dir/mail
		sendmail $EMAILRECIPIENT < $dir/mail
		rm $dir/createdb.sql $dir/mail $dir/mysqlpasswd $dir/utilities.list $dir/white.list $dir/usersftp.list
		export DEBIAN_FRONTEND=dialog
		exit 0
	fi
