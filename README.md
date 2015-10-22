# server-install
##### Pull request are welcome on `experimental` branch
Server post installation scripts.

## web-server-install.bash
##### Fully Ubuntu compatible to test with debian
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
- Ip to whitelist
- FTP users to create
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
