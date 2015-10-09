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
	UTILS="$dir/utilities.list"	#Please don't modify unless you know what you are doing
	WHITE="$dir/white.list"	#Please don't modify unless you know what you are doing
	USERSFTP="$dir/usersftp.list" #Please don't modify unless you know what you are doing
	hostn="srv.example.com"	#Server Hostname (Please use a FSQN and don't forget to setup your PTR)
	CLEF_SSH='KEY1\nKEY2\KEY3' 	#Separate Key with \n
	EMAILRECIPIENT='me@example.com, my_colleague@example.com, another_colleague@example.com' #A mail will be sent to theese with the differents passwords generated Followed by the Error Log, there's no email adress limit
	MONITSERVER="mmonit.example.com" #M/Monit Server FQDN or IP Address
	MONITUSER="mmonituser" #Distant M/Monit User
	MONITPASSWORD="mmonitpasswd" #Distant M/Monit User Password
	SSH_PORT="22" #SSH Listening port, 22 is default, I recommend to change it

#GET du Utilities depuis le NAS (Don't mind this comment)
#Si pas de NAS (Don't mind this comment)
#Package You want to install
#The default list should be enough
#But feel free to add others
#Please keep in mind that if you add your own packages
#that prompts could show up, and you could need human intervention for the script to end
#Please Always put mysql-server first

cat >> $dir/utilities.list << EOF
mysql-server
nginx
php5-fpm
php5-imagick
php5-gd
php5-mcrypt
php5-mysql
apg
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
#Password will be autogenerated
#Default home is /home/$username
cat >> $dir/usersftp.list << EOF
username1
username2
EOF
#Fin Si pas de NAS (Don't mind this comment)

##############################
#----- FIN DECLARATIONS -----#
##############################

	echo "subject : fin de l'installation de $hostn" > $dir/mail

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
	
	#Install GEOIP
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
	cd $dir

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
	iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
	iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
	iptables -t filter -A INPUT -p tcp --dport 21 -j ACCEPT
			
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	
	iptables -A INPUT -m geoip --source-country RU,CN,UA,TW,TR,SK,RO,PL,CZ,BG  -j DROP #Blocking potential botnet zone (No offense intended if you live here, but it's my client policy...)

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

		for paquet in $(cat $UTILS)
		do
			echo -e '\t'$paquet
						
			#MYSQL PreInstall & Install
			
			if [ "$paquet" = "mysql-server" ]
			then
					#Mysql Passwd gen
					apt-get install -y -q --no-install-recommends apg
					apg -q -a  0 -n 1 -m 12 -M NCL >"$dir/mysqlpasswd"
					mysqlpasswd=`cat $dir/mysqlpasswd`
					echo "mysql-server mysql-server/root_password password $mysqlpasswd" | debconf-set-selections
					echo "mysql-server mysql-server/root_password_again password $mysqlpasswd" | debconf-set-selections
					#Install
					apt-get install mysql-server -y

				echo "Mysql user : root"  >> $dir/mail 
				echo "Mysql root Password : $mysqlpasswd"  >> $dir/mail
				echo ""  >> $dir/mail
			else
				#installation du paquet
				apt-get install $paquet -y
			fi 
		done

#Paquets SetUp
	for paquet in $(cat $UTILS)
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

    location ~ \\.php$ {
        fastcgi_pass unix:/var/run/php5-fpm.sock;
        fastcgi_split_path_info ^(.+\\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root$fastcgi_script_name;
        fastcgi_param HTTPS off;
    }
}

EOF

				service nginx restart

				;;

				"monit")

					# Monit Setup

					rm /etc/monit/monitrc
					cat >> /etc/monit/monitrc << EOF
set alert $EMAILRECIPIENT
set mail-format {
	from: monit@ \$HOST
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
	if loadavg (5min) > 3 then alert
	if loadavg (15min) > 1 then alert
	if memory usage > 80% for 4 cycles then alert
	if swap usage > 20% for 4 cycles then alert
	# Test the user part of CPU usage 
	if cpu usage (user) > 80% for 2 cycles then alert
	# Test the system part of CPU usage 
	if cpu usage (system) > 20% for 2 cycles then alert
	# Test the i/o wait part of CPU usage 
	if cpu usage (wait) > 80% for 2 cycles then alert
	if cpu usage > 75% for 2 cycles then alert
	if cpu usage > 100% for 2 cycles then alert	
	if cpu usage > 200% for 4 cycles then alert	
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

check process mysql with pidfile /opt/mysql/data/myserver.mydomain.pid
	group database
	start program = "/etc/init.d/mysql start"
	stop program = "/etc/init.d/mysql stop"
	if failed host 192.168.1.1 port 3306 protocol mysql then alert
	depends on mysql_bin
	depends on mysql_rc

check file mysql_bin with path /opt/mysql/bin/mysqld
	group database
		if failed checksum then unmonitor
	if failed permission 755 then unmonitor
	if failed uid root then unmonitor
	if failed gid root then unmonitor

check file mysql_rc with path /etc/init.d/mysql
	group database
	if failed checksum then unmonitor
	if failed permission 755 then unmonitor
	if failed uid root then unmonitor
	if failed gid root then unmonitor

check process sshd with pidfile /var/run/sshd.pid
	start program  "/etc/init.d/sshd start"
	stop program  "/etc/init.d/sshd stop"
	if failed port 4096 protocol ssh then alert

EOF
			;;
				"pure-ftpd-mysql")
				
					# Pureftpd-mysql Setup

					openssl rand -base64 8 | sed s/=// > $dir/pureftpdpasswd
					ftpdpasswd=`cat $dir/pureftpdpasswd` 

					cat > $dir/createdb.sql << EOF

#Creating Database for pure-ftpd-mysql
#With user 'pureftpd', the password is randomly generated
CREATE DATABASE pureftpd;
USE pureftpd;
CREATE TABLE ftpd ( User varchar(16) NOT NULL default '', status enum('0','1') NOT NULL default '0', Password varchar(64) NOT NULL default '', Uid varchar(11) NOT NULL default '-1', Gid varchar(11) NOT NULL default '-1', Dir varchar(128) NOT NULL default '', ULBandwidth smallint(5) NOT NULL default '0', DLBandwidth smallint(5) NOT NULL default '0', comment tinytext NOT NULL, ipaccess varchar(15) NOT NULL default '*', QuotaSize smallint(5) NOT NULL default '0', QuotaFiles int(11) NOT NULL default 0, PRIMARY KEY (User), UNIQUE KEY User (User));
CREATE USER 'pureftpd'@'localhost' IDENTIFIED BY 'tototo';
GRANT all ON pureftpd.* TO 'pureftpd'@'localhost';
FLUSH PRIVILEGES;
EOF

					sed -i "s/tototo/$ftpdpasswd/g" $dir/createdb.sql
					mysql -u root -p$mysqlpasswd < $dir/createdb.sql
					
					echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
					echo "/etc/pure-ftpd/db/mysql.conf" > /etc/pure-ftpd/conf/MySQLConfigFile
					echo "yes" > /etc/pure-ftpd/conf/CreateHomeDir
					echo "yes" > /etc/pure-ftpd/ChrootEveryone
					echo "yes" > /etc/pure-ftpd/conf/DontResolve

					cat > /etc/pure-ftpd/db/mysql.conf << EOF
					
MYSQLSocket      /var/run/mysqld/mysqld.sock
MYSQLServer     localhost
MYSQLPort       3306
MYSQLUser       pureftpd
MYSQLPassword   $ftpdpasswd
MYSQLDatabase   pureftpd
MYSQLCrypt      md5
MYSQLGetPW      SELECT Password FROM ftpd WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MYSQLGetUID     SELECT Uid FROM ftpd WHERE User="\L" AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MYSQLGetGID     SELECT Gid FROM ftpd WHERE User="\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MYSQLGetDir     SELECT Dir FROM ftpd WHERE User="\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MySQLGetBandwidthUL SELECT ULBandwidth FROM ftpd WHERE User="\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MySQLGetBandwidthDL SELECT DLBandwidth FROM ftpd WHERE User="\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MySQLGetQTASZ   SELECT QuotaSize FROM ftpd WHERE User="\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
MySQLGetQTAFS   SELECT QuotaFiles FROM ftpd WHERE User="\L"AND status="1" AND (ipaccess = "*" OR ipaccess LIKE "\R")
EOF
					
					/etc/init.d/pure-ftpd-mysql restart

				wget -q https://raw.githubusercontent.com/Cthulhuely/PostInstallScript/master/insertftpduser.bash #Get ftp users creation script from my github
				#Pour l'infra distribuée Get depuis le NAS (Don't Mind this comment)

				echo "Mysql user for Pureftpd : pureftpd" >> $dir/mail 
				echo "Mysql Password for Pureftpd : $ftpdpasswd"  >> $dir/mail
				#Creating FTP Users Defined in Declarations
				for ftpuser in $(cat $USERSFTP)
					do
					openssl rand -base64 8 | sed s/=// > "$dir/userpasswd"
					userpasswd=`cat $dir/userpasswd`
					bash insertftpduser.bash $ftpuser /home/$ftpuser $userpasswd
					echo "Pureftpd user : $ftpuser" >> $dir/mail 
					echo "$ftpuser homedir : /home/$ftpuser" >> $dir/mail
					echo "$ftpuser ftp password : $userpasswd" >> $dir/mail 
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
		HostKey /etc/ssh/ssh_host_dsa_key
		HostKey /etc/ssh/ssh_host_ecdsa_key
		HostKey /etc/ssh/ssh_host_ed25519_key
		UsePrivilegeSeparation yes
		KeyRegenerationInterval 3600
		ServerKeyBits 1024
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
	apt-get autoremove -y
	apt-get clean
	

	if [ -s /var/log/PostInstall.log ]
	then
		cat /var/log/PostInstall.log 
		cat /var/log/PostInstall.log  >> $dir/mail
		sendmail $EMAILRECIPIENT < $dir/mail
		rm $dir/createdb.sql $dir/mail $dir/mysqlpasswd $dir/utilities.list $dir/white.list $dir/usersftp.list
		exit 1
	else
		echo 'Fin du script sans erreurs \o/' >> /var/log/PostInstall.log
		cat /var/log/PostInstall.log  >> $dir/mail
		sendmail $EMAILRECIPIENT < $dir/mail
		rm $dir/createdb.sql $dir/mail $dir/mysqlpasswd $dir/utilities.list $dir/white.list $dir/usersftp.list
		exit 0
	fi
