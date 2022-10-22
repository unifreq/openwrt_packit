#!/bin/bash
/usr/bin/mkimage -C none -A arm -T script -n 'flatmax load script' \
	-d ../../bootfiles/rockchip/rk3588/h88k/boot.cmd \
	../../bootfiles/rockchip/rk3588/h88k/boot.scr
