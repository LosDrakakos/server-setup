# server-install
##### Pull request are welcome on `experimental` branch
This is a collection of bash scripts (for now, some python scripts will follow) with purpose of server setup & deployment.

## web-server-install.bash
##### Fully Ubuntu compatible | Not tested With Debian but should work
Bash script that install and configure a fully operational Web server
By default it install the following package :

- mysql-server
- nginx
- php5-fpm
- php5-imagick
- php5-gd
- php5-mcrypt
- php5-mysql
- apg
- monit
- pure-ftpd-mysql
- rkhunter
- postfix

All these package are installed without any prompts (so it's suitable for dedicated server post-installation)

You need to edit the values in the `DECLARATION` Zone

Delimited by
>```
##########################
#----- DECLARATIONS -----#
##########################
```

and

>```
##############################
#----- FIN DECLARATIONS -----#
##############################
```

##### It is possible to set the following parameters :
- Ip to whitelist (l. 61)
 >IP you want to bypasss the firewall (please only use static IP you own, could be dangerous otherwise)

 >IP Format is `X.X.X.X/XX`

 >If your home public IP is `123.123.123.123`

 >Just type in `123.123.123.123/32` but wider range are supported ;)
 >
```shell
cat >> $dir/white.list << EOF
X.X.X.X.X/XX
X.X.X.X.X/XX
EOF
```

- FTP users to create (l. 75)
 >Obviously you'll need to add `pure-ftpd-mysql` to the `utilities.list`

 >Syntax is `username:/home/directory:password`
If you want a randomly generated password just type `random` in the password field.
>In the example below, username1's password will be `username1password`
but username2's password will be randomly generated
>
```shell
cat >> $dir/usersftp.list << EOF
username1:/home/username1:username1password
username2:/home/username2:random
EOF
```

- SSH Keys (l. 24)
 >You keys will be added to the root user
 >Just add your public keys separeted with `\n` (no spaces)
```shell
CLEF_SSH='KEY1\nKEY2\KEY3'
```

- SSH Listening port (l 30)
 > It is set by default to 22. although i strongly advise to change it to something less known
 >
```shell
 SSH_PORT="22"
 ```

- Email for end of script report (l. 25)
 > This is mostly for password communication
 > You can put as many adresses as you want, just separate them with `, ` like in the example below
 ```shell
 EMAILRECIPIENT='me@example.com, my_colleague@example.com, another_colleague@example.com'
 ```

- Monit Monitoring helped via MMonit (l. 26)

 >Just fill in thoose parameters, the script will do the rest.
If you don't have a M/Monit server, just leave  MONITSERVER & MONITUSER & MONITPASSWORD to their default values

 >
 ```shell
#PLEASE ONLY USE ONE ADRESS HERE
MONITRECIPIENT='me@example.com' #Address that will be directly alerted by monit (mmonit notif are independant)
MONITSERVER="mmonit.example.com" #M/Monit Server FQDN or IP Address
MONITUSER="mmonituser" #Distant M/Monit User
MONITPASSWORD="mmonitpasswd" #Distant M/Monit User Password
```

- Packages to install (l. 46)

 >Warning it could add prompts if the package is not specified as supported or in the default setup, though most packages won't cause any trouble and will just end with default configuration, some others (like DBMS) could prompt you for passwords or parameters and it would compromise a headless fully automatized post-install.

 >The default list should be enough but feel free to add others. Please keep in mind that if you add your own packages prompts could show up, and that you could need human intervention for the script to end.
 >Packages currently fully-supported :
 >>mysql-server, nginx, php5-fpm, monit, pure-ftpd-mysql, laravel, prestashop1.6

 >Please Always put `mysql-server`  in first postition, then server packages (web servers, php modules, ftp server, etc) and CMS (`prestashop1.6` and/or `laravel`) last

 >See below the default package bundle :

 >
 ```shell
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
```

- If you are running in an OpenVZ CT (l .23)
  > Set `ISVZ` to `True`, there is an issue between OpenVZ Kernel and some iptables modules, it prevents from using those troublesomes modules. (No Issues with LXC so far)
  ```shell
  ISVZ="False" # If the system is in container and does not have its own Kernel (Like OpenVZ)
  ```

#### In progress

- Bug fixes and general enhancement

#### To do

- Add Apache2 to fully supported paquet list
- Add more packages
- Add a fully fonctionnal and user friendly mail server (something like a postfix-admin + roundcube but with a sexier UI)
