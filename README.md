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

You need to edit the values in the `DECLARATION` Zone (Delimited by `#----- DECLARATIONS -----#` and `#----- FIN DECLARATIONS -----#`

It's possible to add :
- Ip to whitelist (l. 61)
```shell
#IP you want to bypasss the firewall (please only use static IP you own, could be dangerous otherwise)
#IP Format xxx.xxx.xxx.xxx/xx
cat >> $dir/white.list << EOF
X.X.X.X.X/XX
X.X.X.X.X/XX
EOF
```
- FTP users to create
```shell
#FTPUserTo create Automatically
#Syntax is username:/home/directory:password
#If you want a randomly generated password just type 'random' in the password field
#In the example below, username1's password will be 'username1password'
#but username2's passxord will be randomly generated
cat >> $dir/usersftp.list << EOF
username1:/home/username1:username1password
username2:/home/username2:random
EOF
```
- Packages to install (Warning it could add prompts)
- SSH Keys
- Email for reporting
- Monitoring via MMonit

#### In progress

- Prestashop auto install (added as a package)
- Bug fixes and general enhancement

#### To do

- Add Apache2 to fully supported paquet list
- Add more CMS auto install
- Add a fully fonctionnal and user friendly mail server (something like a postfix-admin + roundcube)
