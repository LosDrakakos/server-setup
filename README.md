# PostInstallScript
Server post installation scripts (Mainly suited for debian based distro)

Only one script for now, more comming soon.

# DefaultWebServer.sh

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

You need to edit the values in the "DECLARATION" Zone (Delimited by "#----- DECLARATIONS -----#" and "#----- FIN DECLARATIONS -----#"

It's possible to add :
- Ip to whitelist
- FTP users to create
- Packages to install (Warning it could add prompts)
- SSH Keys
- Email for reporting
- Monitoring via MMonit
