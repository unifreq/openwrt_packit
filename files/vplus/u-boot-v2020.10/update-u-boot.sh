#!/bin/bash
if [ $# -eq 0 ];then
	echo "用法: $0  mmcblk0(或mmcblk1)"
	exit 1
fi
MMC=$1
if [ ! -b /dev/$MMC ];then
	echo "$MMC 设备不存在！"
	exit 1
fi

if [ -f u-boot-sunxi-with-spl.bin ];then
	dd if=u-boot-sunxi-with-spl.bin of=/dev/$MMC bs=1024 seek=8 conv=fsync
elif [ -f sunxi-spl.bin -a -f u-boot.itb ];then
	dd if=sunxi-spl.bin of=/dev/$MMC bs=1024 seek=8 conv=fsync
	dd if=u-boot.itb of=/dev/$MMC bs=1024 seek=40 conv=fsync
else
	echo "no u-boot file found!"
	exit 1
fi
sync
