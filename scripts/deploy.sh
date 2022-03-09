#!/bin/bash
set -o errexit -o pipefail -o noclobber -o nounset
! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo '[$0] Requires `getopt`.'  >> INSTALL_LOG
    exit 1
fi

OPTIONS=cei
LONGOPTS=captcha,email,inviteonly

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
        --)
            shift
            break
            ;;
        *)
            echo "[$0] Unhandled option." >> INSTALL_LOG
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

echo "Cloning self host project from: 'https://github.com/revoltchat/self-hosted'" >> INSTALL_LOG
git clone https://github.com/revoltchat/self-hosted revolt
chown -R docker. /root/revolt
cd /root/revolt/
cp .env.example .env
# Update settings in environment file
url=$(printf '%s\n' "$url" | sed -e 's/[]\/$*.^[]/\\&/g'); # Put relevant escape characters into url string 
sed -i "s/http:\/\/local.revolt.chat/$url/" .env
sed -i "s/REVOLT_UNSAFE_NO_CAPTCHA=/REVOLT_UNSAFE_NO_CAPTCHA=$captcha # Default: /" .env
sed -i "s/REVOLT_INVITE_ONLY=/REVOLT_INVITE_ONLY=$inviteonly # Default: /" .env
sed -i "s/REVOLT_UNSAFE_NO_EMAIL=/REVOLT_UNSAFE_NO_EMAIL=$email # Default: /" .env
if [[ $email -eq 0 ]]; then
    sed -i "s/# REVOLT_SMTP_USERNAME=noreply@example.com/REVOLT_SMTP_USERNAME=noreply@za.cloudlet.cloud/" .env
    sed -i "s/# REVOLT_SMTP_HOST=smtp.example.com/REVOLT_SMTP_HOST=smtp.example.com/" .env
    sed -i "s/# REVOLT_SMTP_FROM=Revolt <noreply@example.com>/REVOLT_SMTP_FROM=Revolt <noreply@za.cloudlet.cloud>/" .env
fi
docker-compose up -d
