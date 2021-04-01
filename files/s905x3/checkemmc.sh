#!/bin/sh

SKIP1=68
BOOT=160
ROOT1=960
SKIP2=162
ROOT2=960

TARGET_SHARED_FSTYPE=btrfs

hasdrives=$(lsblk | grep -oE '(mmcblk[0-9])' | sort | uniq)
if [ "$hasdrives" = "" ]
then
	echo "本系统中未找到任何 EMMC 或 SD 设备!!! "
	exit 1
fi

avail=$(lsblk | grep -oE '(mmcblk[0-9]|sda[0-9])' | sort | uniq)
if [ "$avail" = "" ]
then
	echo "本系统未找到任何可用的磁盘设备!!!"
	exit 1
fi

runfrom=$(lsblk | grep -e '/$' | grep -oE '(mmcblk[0-9]|sda[0-9])')
if [ "$runfrom" = "" ]
then
	echo " 未找到根文件系统!!! "
	exit 1
fi

emmc=$(echo $avail | sed "s/$runfrom//" | sed "s/sd[a-z][0-9]//g" | sed "s/ //g")
if [ "$emmc" = "" ]
then
	echo " 没找到空闲的EMMC设备，或是系统已经运行在EMMC设备上了!!!"
	exit 1
fi

if [ "$runfrom" = "$avail" ]
then
	echo " 你的系统已经运行在 EMMC 设备上了!!! "
	exit 1
fi

if [ $runfrom = $emmc ]
then
	echo " 你的系统已经运行在 EMMC 设备上了!!! "
	exit 1
fi

if [ "$(echo $emmc | grep mmcblk)" = "" ]
then
	echo " 你的系统上好象没有任何 EMMC 设备!!! "
	exit 1
fi

