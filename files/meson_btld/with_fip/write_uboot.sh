#!/bin/bash

if [ $# -ne 2 ];then
	echo "Usage: $0 u-boot-file mmc-device-path"
	exit 1
fi
FILE=$1
DEV=$2
if [ ! -f "$FILE" ];then
	echo "u-boot-file [$FILE] is not exists!"
	exit 1
fi

if [ ! -b "$DEV" ];then
	echo "mmc-device-path [$DEV] is not exists!"
	exit 1
fi

echo "dd if=${FILE} of=${DEV} conv=fsync,notrunc bs=512 skip=1 seek=1"
dd if=${FILE} of=${DEV} conv=fsync,notrunc bs=512 skip=1 seek=1
echo "dd if=${FILE} of=${DEV} conv=fsync,notrunc bs=1 count=444"
dd if=${FILE} of=${DEV} conv=fsync,notrunc bs=1 count=444
