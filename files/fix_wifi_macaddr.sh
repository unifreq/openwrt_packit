#!/bin/bash

FILE="/lib/firmware/brcm/brcmfmac43455-sdio.phicomm,n1.txt"
ETH0_MAC=$(ifconfig eth0 | grep HWaddr | awk '{print $5}')
CUR_WIFI_MAC=$(cat "$FILE" | find_macaddr.pl)
NEW_WIFI_MAC=$(echo $ETH0_MAC | inc_macaddr.pl -1)
if [ $CUR_WIFI_MAC != $NEW_WIFI_MAC ];then
	sed -e "s/${CUR_WIFI_MAC}/${NEW_WIFI_MAC}/" -i "$FILE"
fi
