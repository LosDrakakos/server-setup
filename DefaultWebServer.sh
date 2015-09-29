#!/bin/bash
#Script de déploiement automatique de paquets et de config en PostInstall

# Test que le script est lance en root

	if [ "$(id -u)" != "0" ]; then
		echo "Le script doit être lancé en root: # sudo $0" 1>&2
		exit 1
	fi

#----- DECLARATIONS -----#

	dir="$PWD"
	UTILS="$dir/utilities.list"
	host=DEFINEHOSTNAME

#Changement du hostname
	hostname=$(cat /etc/hostname)
	sed -i "s/$hostname/$host/g" /etc/hosts
	sed -i "s/$hostname/$host/g" /etc/hostname

#Si pas de NAS
	cat >> $dir/utilities.list << EOF
		nginx
		php5-fpm
		php5-imagick
		php5-gd
		php5-mcrypt
		apg
		mysql-server
		monit
EOF

#Ecritures des erreurs dans Variable
	if [ -s /var/log/PostInstall.log ]
		then
		rm /var/log/PostInstall.log
		echo "$(tput setaf 1) ATTENTION LE SCRIPT AVAIT DEJA ETE LANCE$(tput sgr0)"
	fi
	exec 2>>/var/log/PostInstall.log

# Ajout des Clefs SSH 
	mkdir -p /root/.ssh/
	echo -e 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCif5R/a+r0u0VAW+rwCDtiKDEKwWs2jq4a5zbc/mvU28vKlC4eVva6ElRtHsD/laqu2MtpZL/4/rWKCR8zMG9irTi+Xrk4WJXWASRssBikkuon0YQx4kU3f8iXsjZ0GES9cobRfJJMKvhG7Hgvm5alwLecHtUZ+NvJMFWEA6naWa3tZzhkbWiM77dgKOPIBgFJrR7RLsOQLWpZuQLB+oOvGJec1/nbUZiWpNSNf/8CvzhagXadyLiHFQJsk8ToiTqgd7DBVqZ54ar0gEL+1abglpTRJZU2RNFcmlguVFqMAmhLYNWd0XBwvCFzW49te5AnS+0E8ttqxNnQ+SVQ+djE7Qvf81Ec0s3WNnbtSfSObiTrX7ToC/SsCh5JJ21xCWyP3Va1hTHmGdiYbS6Tx/5Ii0rWnvz6CExVSo/Vw/6ZVZTrkDzCEuAR321frXf84qoZOMVhB58YsY0S/FEhHIlrNd5NtByOtfdyVFgb9dTGDuFkLGK9r35k4CtHLNDtxSSRJIFIgiRD/v8UZm64yPZwptVeU3P/zPeTqgf3myh1RsB/845Z8H/Pz1/993ofDQ8i54B5W7zoc8dPSssgoFCpjSsatmhNHtkvDRAwve7jJGTGNkDF/sJ2yfgaWJLkxHvUkn9unM59Ym3alk3ipQg0i0Ah8BsheHO9yR1Qv4e69Q==\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDWh6Eiv0sEkOZ4QQ+h1e+gTQ0x/nK0NGKuvMtvdsleHI7XhK2ArI815ILFkI7b2DlgsRFozAPCu5E1DL58gefyu0XxGSxaANVxPmtWxiSJUaYUQ1FAbmMGKORYMSb79S1sTBb3QMj4bTTVAX1S2g06rF+Uae4DydfPyr/LlRmtcn8AFUcKGop2AR7msU7psHXBLGet+SArynUxqpAC8490+M6XS2sNjnilP+wrq0P/TdtfkQY8jX3yYupWswWJKN8aLQ1Iox45cUDR0f1SkncBQ3rZDibRGrlUyrSQGEP0e/Y8t7DgSyK49nMSUbhvdfJ20k6srpM3gTKpjSiPuvhf gregory@gregory-desktop' >> /root/.ssh/authorized_keys

# Verouillage du Root
	passwd root -l

# Firewall Whitelist
	
	#Install GEOIP
	apt-get install iptables iptables-dev module-assistant xtables-addons-common libtext-csv-xs-perl unzip  -y -q
	module-assistant --verbose --text-mode auto-install xtables-addons -i -q

	cd /usr/lib/xtables-addons/  
	./xt_geoip_dl
	./xt_geoip_build GeoIPCountryWhois.csv
	mkdir -p /usr/share/xt_geoip/  
	cp -r {BE,LE} /usr/share/xt_geoip/
	cd $dir
#Whitelist
	iptables -F
	iptables -t filter -P INPUT DROP
	iptables -t filter -P INPUT DROP
	
	iptables -t filter -A INPUT -i lo -j ACCEPT
	iptables -t filter -A OUTPUT -o lo -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 21 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
	iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
	iptables -t filter -A OUTPUT -p udp --dport 123 -j ACCEPT
	iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
	iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
	iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
	
	
	
	iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
	
	iptables -A INPUT -m geoip --source-country RU,CN,UA,TW,TR,SK,RO,PL,CZ,BG  -j DROP
	iptables -A INPUT -s 88.163.22.99/32 -j ACCEPT
	iptables -A INPUT -s 90.63.178.63/32 -j ACCEPT
	iptables -A INPUT -s 78.226.56.137/32 -j ACCEPT
	iptables -A INPUT -s 51.254.154.0/26 -j ACCEPT
	
	iptables-saves > /root/iptablesbkp
	
	echo "/sbin/iptables-restore < /root/iptablesbkp" >> /etc/rc.local
	
# Update&Upgrade

	apt-get update -y
# Upgrade  
	apt-get upgrade -y

#Installation des Paquets de services
	echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
	echo "postfix postfix/mailname string $host" | debconf-set-selections
	apt-get install rkhunter postfix -y

	#TODO Ajouter get de utilities.list depuis le NAS dédié au site afin de personnaliser le déploiement en fonction du site

		for paquet in $(cat $UTILS)
		do
			echo -e '\t'$paquet
						
			#MYSQL
			
			if [ "$paquet" = "mysql-server" ]
			then
					#Génération du Passwd mysql
					apt-get install -y -q --no-install-recommends apg
					apg -q -a  0 -n 1 -m 12 -M NCL >"$dir/mysqlpasswd"
					mysqlpasswd=$dir/mysqlpasswd
					echo "mysql-server mysql-server/root_password password $mysqlpasswd" | debconf-set-selections
					echo "mysql-server mysql-server/root_password_again password $mysqlpasswd" | debconf-set-selections
					#Install
					apt-get install mysql-server -y
					
			else
				#installation du paquet
				apt-get install $paquet -y
			fi 
		done

#Configuration des Paquets
	for paquet in $(cat $UTILS)
		do
			case "$paquet" in
				
				"php5-fpm")


					# Paramétrage php5-fpm

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
						[SQL]
						sql.safe_mode = Off
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

				# Paramétrage php5-fpm
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
						javascript;
						fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=nginxcache:10m inactive=1h max_size=1g;
						include /etc/nginx/conf.d/*.conf;
						include /etc/nginx/sites-enabled/*;
					}
					
EOF
				
				service nginx restart

				;;

				"monit")


					# Paramétrage monit

					rm /etc/monit/monitrc
					cat >> /etc/monit/monitrc << EOF
						set alert marcopoulos@antadis.com
						 set mail-format {
 						from: monit@$HOST
 						subject: $SERVICE $EVENT at $DATE
 						message: Monit $ACTION $SERVICE at $DATE on $HOST: $DESCRIPTION.
 						Yours sincerely,
 						monit
 						}
						set daemon 60           
                				set logfile /var/log/monit.log
  						set idfile /var/lib/monit/id

  						set eventqueue
    						basedir /var/lib/monit/events
    						slots 100
    						set mmonit http://USER:PASSWORD@SERVER:PORT/collector
						set httpd port 2812
						allow localhost
						allow 51.254.129.104
						allow USER:PASWORD
						include /etc/monit/conf.d/*

						check system $HOST
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
							if failed port 22 protocol ssh then alert


EOF
				;;

			esac				

		done
# Paramétrage SSH
	rm /etc/ssh/sshd_config 
	cat >> /etc/ssh/sshd_config  << EOF
		Port 4096
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

#Clean du sytème
	apt-get autoremove -y
	apt-get clean
	/var
	if [ -s /var/log/PostInstall.log ]
	then
		cat /var/log/PostInstall.log 
		exit 1
	else
		echo 'Fin du script sans erreurs \o/' >> /var/log/PostInstall.log 
		cat /var/log/PostInstall.log 
		exit 0
	fi
