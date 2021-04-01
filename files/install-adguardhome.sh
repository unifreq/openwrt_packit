#!/bin/sh
docker pull adguard/adguardhome:arm64-latest
mkdir -p /mnt/mmcblk1p3/adguardhome/workdir /mnt/mmcblk1p3/adguardhome/confdir
docker run --name adguardhome \
	-v /mnt/mmcblk1p3/adguardhome/workdir:/opt/adguardhome/work \
	-v /mnt/mmcblk1p3/adguardhome/confdir:/opt/adguardhome/conf \
	--restart always \
	-p 9053:53/tcp -p 9053:53/udp \
	-p 9067:67/udp -p 9068:68/tcp -p 9068:68/udp \
	-p 9080:80/tcp -p 9443:443/tcp \
	-p 9853:853/tcp \
	-p 3000:3000/tcp \
	-d adguard/adguardhome:arm64-latest
