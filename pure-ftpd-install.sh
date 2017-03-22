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
USERSFTP="$dir/usersftp.list" #Please don't modify unless you know what you are doing

#FTPUserTo create Automatically
#Syntax is username:/home/directory:password
#If you want a randomly generated password just type 'random' in the password field
#In the example below, username1's password will be 'username1password'
#but username2's passxord will be randomly generated
cat >> $dir/usersftp.list << EOF
username1:/home/username1:username1password
username2:/home/username2:random
EOF

# Pureftpd-mysql Setup
openssl rand -base64 12 > $dir/pureftpdpasswd
ftpdpasswd=$(cat $dir/pureftpdpasswd)

# Install mariaDB
apt install mariadb-server pure-ftpd-mysql -y

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

mysql -u root < $dir/createdb.sql
echo "40110 40210" > /etc/pure-ftpd/conf/PassivePortRange
echo "yes" > /etc/pure-ftpd/conf/NoAnonymous
echo "/etc/pure-ftpd/db/mysql.conf" > /etc/pure-ftpd/conf/MySQLConfigFile
echo "yes" > /etc/pure-ftpd/conf/CreateHomeDir
echo "yes" > /etc/pure-ftpd/conf/ChrootEveryone
echo "yes" > /etc/pure-ftpd/conf/DontResolve
echo "32" > /etc/pure-ftpd/conf/MinUID
echo "no" > /etc/pure-ftpd/conf/UnixAuthentication
echo "yes" > /etc/pure-ftpd/conf/DisplayDotFiles
echo "yes" > /etc/pure-ftpd/conf/VerboseLog
iptables -A INPUT -p tcp --match multiport --dports 40110:40210 -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport 21 -j ACCEPT
iptables-save > /root/iptablesbkp

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
	cd $dir/scripts | exit 1
	wget -q https://raw.githubusercontent.com/cthulhuely/server-setup/experimental/scripts/insertftpduser.bash #Get ftp users creation script from my github
	cd $dir | exit 1
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
done

echo $dir/mail
