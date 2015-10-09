#!/bin/bash
#Creation d'utlisateur pureftpd
if [[ -z "$1" ]]; then
	echo "Rappel sur l'utilisation de la commande : $0 Username home password" 1>&2
	exit 1
fi
if [[ -z "$2" ]]; then
	echo "Rappel sur l'utilisation de la commande : $0 Username home password" 1>&2
	exit 1
fi
if [[ -z "$3" ]]; then
	echo "Rappel sur l'utilisation de la commande : $0 Username home password" 1>&2
	exit 1
fi

ftpdpasswd=`cat $PWD/pureftpdpasswd\`
Username="$1"
Directory="$2"
Password="$3"

echo "use pureftpd;" > insertftpduser.sql
echo "INSERT INTO \`ftpd\` (\`User\`, \`status\`, \`Password\`, \`Uid\`, \`Gid\`, \`Dir\`, \`ULBandwidth\`, \`DLBandwidth\`, \`comment\`, \`ipaccess\`, \`QuotaSize\`, \`QuotaFiles\`) VALUES ('$Username', '1', MD5('$Password'), '33', '33', '$Directory', '0', '0', '', '*', '0', '0');" >> insertftpduser.sql

mysql -u pureftpd -p$ftpdpasswd < insertftpduser.sql
