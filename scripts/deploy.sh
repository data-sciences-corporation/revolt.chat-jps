#!/bin/bash
script="deploy.sh"
logfile="/var/log/jps-revolt-install.log"
set -o errexit -o pipefail -o noclobber -o nounset
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo '[$script] Requires `getopt`.' >> $logfile
    exit 1
fi

OPTIONS=ceip:
LONGOPTS=captcha,email,inviteonly,password:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"

captcha=1 
email=1 
inviteonly=1
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -c|--captcha)
            captcha=0
            shift
            ;;
        -e|--email)
            email=0
            shift
            ;;
        -i|--inviteonly)
            inviteonly=0
            shift
            ;;
        -p|--password)
            password="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "[deploy.sh] Unhandled option [$1]." >> $logfile
            exit 3
            ;;
    esac
done

# handle non-option arguments
if [[ $# -ne 1 ]]; then
    echo "[$script] A URL is required." >> $logfile
    exit 4
fi
url=$1
echo "[$script] Cloning Revolt.chat 'self-hosted' project from: 'https://github.com/revoltchat/self-hosted'" >> $logfile
git clone https://github.com/revoltchat/self-hosted revolt
chown -R docker. /root/revolt
cd /root/revolt/
cp .env.example .env
echo "[$script] Configuring user environment." >> $logfile
echo -e "----->[$script]\n<0-yes> <1-no>\n captcha: $captcha\n email: $email\n inviteonly: $inviteonly\n url: $url\n<-----" >> $logfile
# Configure the revolt URL
url=$(printf '%s\n' "$url" | sed -e 's/[]\/$*.^[]/\\&/g'); # Put relevant escape characters into url string 
sed -i "s/http:\/\/local.revolt.chat/$url/" .env
wsurl=$(echo $url | sed "s/http/ws/")
sed -i "s/ws:\/\/local.revolt.chat/$wsurl/" .env
# REVOLT_EXTERNAL_WS_URL=ws://local.revolt.chat:9000
# Disable/Enable the captcha services
sed -i "s/REVOLT_UNSAFE_NO_CAPTCHA=.*/REVOLT_UNSAFE_NO_CAPTCHA=$captcha/" .env
# Disable/Enable the 'Invite only' services
sed -i "s/REVOLT_INVITE_ONLY=.*/REVOLT_INVITE_ONLY=$inviteonly/" .env
# Enable email notifications
sed -i "s/REVOLT_UNSAFE_NO_EMAIL=.*/REVOLT_UNSAFE_NO_EMAIL=$email/" .env
if [[ $email -eq 0 ]]; then
    sed -i "s/# REVOLT_SMTP_USERNAME=noreply@example.com/REVOLT_SMTP_USERNAME=noreply@za.cloudlet.cloud/" .env
    sed -i "s/# REVOLT_SMTP_HOST=smtp.example.com/REVOLT_SMTP_HOST=smtp.example.com/" .env
    sed -i "s/# REVOLT_SMTP_FROM=Revolt <noreply@example.com>/REVOLT_SMTP_FROM=Revolt <noreply@za.cloudlet.cloud>/" .env
fi
# Configure random password for S3 service
sed -i "s/MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=$password/" .env
# Generate VAPID keys for push notifications
openssl ecparam -name prime256v1 -genkey -noout -out vapid_private.pem
private_key=$(base64 vapid_private.pem | tr -d '\n')
public_key=$(openssl ec -in vapid_private.pem -outform DER | tail -c 65 | base64 | tr '/+' '_-' | tr -d '\n' | grep -v 'EC Key')
sed -i "s/REVOLT_VAPID_PRIVATE_KEY=.*/REVOLT_VAPID_PRIVATE_KEY=$private_key/" .env
sed -i "s/REVOLT_VAPID_PUBLIC_KEY=.*/REVOLT_VAPID_PUBLIC_KEY=$public_key/" .env
sed -i "/# --> Please replace these.*/d" .env # Clean create key warning
# Update minio endpoint
#sed -i "s/AUTUMN_S3_ENDPOINT=.*/AUTUMN_S3_ENDPOINT=localhost:10000/" .env
echo "[$script] Running docker compose with custom configuration." >> $logfile
# Deploy Revolt.chat services
docker-compose up -d
