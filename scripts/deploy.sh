#!/bin/bash
fqdn=$1
public_ip=$2
echo "Cloning self host project from: 'https://github.com/revoltchat/self-hosted'" >> INSTALL_LOG
git clone https://github.com/revoltchat/self-hosted revolt
chown -R docker. /root/revolt
#docker-compose up -d
echo "Deploying container on IP [$public_ip] and URL [$fqdn]" >> INSTALL_LOG
