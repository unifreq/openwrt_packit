#!/bin/bash

MYSELF=/usr/bin/mk_newpart.sh
DEV=mmcblk0
TOTAL_SIZE=$(lsblk -l -b -I 179 -o NAME,MAJ:MIN,SIZE | grep "179:0" | awk '{print $3}')
TARGET_ROOTFS2_FSTYPE=btrfs
TARGET_SHARED_FSTYPE=btrfs

SKIP_MB=$(awk '{print $1}' /etc/part_size)
BOOT_MB=$(awk '{print $2}' /etc/part_size)
ROOTFS_MB=$(awk '{print $3}' /etc/part_size)

START_P3=$(( (SKIP_MB + BOOT_MB + ROOTFS_MB) * 2048 ))
END_P3=$((ROOTFS_MB * 2048 + START_P3 -1))
START_P4=$((END_P3 + 1))
END_P4=$((TOTAL_SIZE / 512 - 1))

cat > /tmp/fdisk.script <<EOF
n
p
3
$START_P3
$END_P3
n
p
$START_P4
$END_P4
t
3
83
t
4
83
w
EOF

fdisk /dev/$DEV < /tmp/fdisk.script
if [ $? -ne 0 ];then
	echo "fdisk failed, restore the backup bootloader, and abort"
	sync
	exit 1
fi
echo "fdisk done"
echo

# mkfs
echo "create rootfs2 filesystem ... "
case $TARGET_ROOTFS2_FSTYPE in
	xfs) mkfs.xfs -f -L EMMC_ROOTFS2 /dev/${DEV}p3;;
      btrfs) mkfs.btrfs -f -L EMMC_ROOTFS2 /dev/${DEV}p3;; 
	  *) mkfs.ext4 -F -L EMMC_ROOTFS2  /dev/${DEV}p3;;
esac
echo "done"

echo "create shared filesystem ... "
mkdir -p /mnt/${DEV}p4
case $TARGET_SHARED_FSTYPE in
	xfs) mkfs.xfs -f -L EMMC_SHARED /dev/${DEV}p4
	     mount -t xfs /dev/${DEV}p4 /mnt/${DEV}p4
	     ;;
      btrfs) mkfs.btrfs -f -L EMMC_SHARED /dev/${DEV}p4
	     mount -t btrfs /dev/${DEV}p4 /mnt/${DEV}p4
	     ;; 
	  *) mkfs.ext4 -F -L EMMC_SHARED  /dev/${DEV}p4
	     mount -t ext4 /dev/${DEV}p4 /mnt/${DEV}p4
	     ;;
esac
mkdir -p /mnt/${DEV}p4/docker
rm -rf /opt/docker
ln -sf /mnt/mmcblk0p4/docker/ /opt/docker
/etc/init.d/dockerd restart
if [ -f /etc/config/AdGuardHome ];then
	mkdir -p /mnt/${DEV}p4/AdGuardHome/data
	rm -rf /usr/bin/AdGuardHome
	ln -sf /mnt/${DEV}p4/AdGuardHome /usr/bin/AdGuardHome
fi
sync
echo "done"

rm -f $MYSELF /etc/part_size /tmp/fdisk.script
mv -f /etc/rc.local.orig /etc/rc.local
