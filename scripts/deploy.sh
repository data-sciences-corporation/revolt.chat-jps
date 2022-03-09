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
sed -i 's/http:\/\/local.revolt.chat/$url/' .env
sed -i 's/REVOLT_UNSAFE_NO_CAPTCHA=/REVOLT_UNSAFE_NO_CAPTCHA=$captcha \n# /' .env 
#docker-compose up -d
