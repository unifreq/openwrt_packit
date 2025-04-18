#!/bin/bash

MKIMG="/usr/bin/mkimage"
#MKIMG="../../rk3588/rock5b/mkimage"
$MKIMG -C none -A arm -T script -n 'flatmax load script' -d ../../bootfiles/rockchip/rk3528/e24c/boot.cmd ../../bootfiles/rockchip/rk3528/e24c/boot.scr
