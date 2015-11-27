#!/bin/bash
#backup-script.bash
#No Arguments Taken

#Definitions variables et lists
cat >> /tmp/path-to-backup.list << EOF
/var/www/
/var/lib/mysql/
EOF

backupfolder=root@srv2-cloug.igotta.beer:/var/backup/
sshremoteport=4096

emailrecipient="marcopoulos@antadis.com"

#Debut du Script

if [ -s /var/log/postbackup.log ]
then
	rm /var/log/postbackup.log
fi

exec 2>>/var/log/postbackup.log

for paths in $(cat /tmp/path-to-backup.list)
do
	rsync -artv -e "ssh -p $sshremoteport" $paths $backupfolder
done

echo "subject : $HOST Report de fin de Backup" > /tmp/mail

if [ -s /var/log/postbackup.log ]
then
	echo "Backup du serveur terminé avec erreur." >> /tmp/mail
	echo -e "fichier mal copiés dans $backupfolder :\n" >> /tmp/mail
	cat /tmp/path-to-backup.list >> /tmp/mail
	echo -e "Log d'erreur :\n" >> /tmp/mail
	cat /var/log/postbackup.log  >> /tmp/mail
	sendmail $emailrecipient < /tmp/mail
	rm /tmp/path-to-backup.list /tmp/mail
	exit 1
else
	echo "Backup du serveur terminé sans erreur." >> /tmp/mail
	echo -e "fichier copiés dans $backupfolder :\n" >> /tmp/mail
	cat /tmp/path-to-backup.list >> /tmp/mail
	sendmail $emailrecipient < /tmp/mail
	rm /tmp/path-to-backup.list /tmp/mail
	exit 0
fi
