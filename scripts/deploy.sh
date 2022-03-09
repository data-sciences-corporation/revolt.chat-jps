#!/bin/bash
fqdn=$1
public_ip=$2
echo "Creating directories" >> INSTALL_LOG
mkdir -p /root/revolt/data
chown -R docker. /root/revolt
echo "Deploying container on IP [$public_ip] and URL [$fqdn]" >> INSTALL_LOG
