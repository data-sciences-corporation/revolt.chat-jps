#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo '[$0] Requires `getopt`.'  >> INSTALL_LOG
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
            echo "[$0] Unhandled option [$1]." >> INSTALL_LOG
            exit 3
            ;;
    esac
done

# handle non-option arguments
if [[ $# -ne 1 ]]; then
    echo "[$0] A URL is required." >> INSTALL_LOG
    exit 4
fi
url=$1
echo -e "\n----->[$0]\n<0-yes> <1-no>\n captcha: $captcha\n email: $email\n inviteonly: $inviteonly\n url: $url\n<-----" >> INSTALL_LOG
echo "[$0] Cloning self host project from: 'https://github.com/revoltchat/self-hosted'" >> INSTALL_LOG
git clone https://github.com/revoltchat/self-hosted revolt
chown -R docker. /root/revolt
cd /root/revolt/
cp .env.example .env
# Configure the revolt URL
url=$(printf '%s\n' "$url" | sed -e 's/[]\/$*.^[]/\\&/g'); # Put relevant escape characters into url string 
sed -i "s/http:\/\/local.revolt.chat/$url/" .env
# Disable/Enable the captcha services
sed -i "s/REVOLT_UNSAFE_NO_CAPTCHA=/REVOLT_UNSAFE_NO_CAPTCHA=$captcha # Default: /" .env
# Disable/Enable the 'Invite only' services
sed -i "s/REVOLT_INVITE_ONLY=/REVOLT_INVITE_ONLY=$inviteonly # Default: /" .env
# Enable email notifications
sed -i "s/REVOLT_UNSAFE_NO_EMAIL=/REVOLT_UNSAFE_NO_EMAIL=$email # Default: /" .env
if [[ $email -eq 0 ]]; then
    sed -i "s/# REVOLT_SMTP_USERNAME=noreply@example.com/REVOLT_SMTP_USERNAME=noreply@za.cloudlet.cloud/" .env
    sed -i "s/# REVOLT_SMTP_HOST=smtp.example.com/REVOLT_SMTP_HOST=smtp.example.com/" .env
    sed -i "s/# REVOLT_SMTP_FROM=Revolt <noreply@example.com>/REVOLT_SMTP_FROM=Revolt <noreply@za.cloudlet.cloud>/" .env
fi
# Configure random password for S3 service
sed -i "s/MINIO_ROOT_PASSWORD=minioautumn/MINIO_ROOT_PASSWORD=$password # Default: /" .env
# Generate VAPID keys for push notifications
openssl ecparam -name prime256v1 -genkey -noout -out vapid_private.pem
private_key=$(base64 vapid_private.pem | tr -d '\n')
public_key=$(openssl ec -in vapid_private.pem -outform DER | tail -c 65 | base64 | tr '/+' '_-' | tr -d '\n' | grep -v 'EC Key')
sed -i "s/REVOLT_VAPID_PRIVATE_KEY=.*/# REVOLT_VAPID_PRIVATE_KEY=$private_key/" .env
sed -i "s/REVOLT_VAPID_PUBLIC_KEY=.*/# REVOLT_VAPID_PUBLIC_KEY=$public_key/" .env
sed -i "/# --> Please replace these.*/d" .env # Clean create key warning

# Deploy Revolt.chat services
docker-compose up -d
