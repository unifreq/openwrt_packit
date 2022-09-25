#!/bin/bash
dd if=idbloader.img of=/dev/mmcblk0 bs=512 seek=64 conv=fsync,notrunc
dd if=u-boot.itb of=/dev/mmcblk0 bs=512 seek=16384 conv=fsync,notrunc
sync
