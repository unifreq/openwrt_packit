#!/bin/sh

# EMMC DEVICE MAJOR
DST_MAJ=179

DST_NAME=$(lsblk -l -b -I $DST_MAJ -o NAME,MAJ:MIN,SIZE | grep "${DST_MAJ}:0" | awk '{print $1}')
DST_SIZE=$(lsblk -l -b -I $DST_MAJ -o NAME,MAJ:MIN,SIZE | grep "${DST_MAJ}:0" | awk '{print $3}')

ROOT_NAME=$(lsblk -l -o NAME,MAJ:MIN,MOUNTPOINT | grep -e '/$' | awk '{print $1}')
ROOT_MAJ=$(lsblk -l -o NAME,MAJ:MIN,MOUNTPOINT | grep -e '/$' | awk '{print $2}' | awk -F ':' '{print $1}')

BOOT_NAME=$(lsblk -l -o NAME,MAJ:MIN,MOUNTPOINT | grep -e '/boot$' | awk '{print $1}')
BOOT_MAJ=$(lsblk -l -o NAME,MAJ:MIN,MOUNTPOINT | grep -e '/boot$' | awk '{print $2}' | awk -F ':' '{print $1}')

if [ "$BOOT_MAJ" == "$DST_MAJ" ];then
	echo "the boot is on emmc, cannot update!"
	exit 1
else
	if [ "$ROOT_MAJ" == "$DST_MAJ" ];then
		echo "the rootfs is on emmc, cannot update!"
		exit 1
	fi
fi

BR_FLAG=1
echo -ne "Do you want to backup old config files and restore to new system? y/n [y]\b\b"
read yn
case $yn in 
	n*|N*) BR_FLAG=0;;
esac

# backup old bootloader
if [ ! -f bootloader-backup.bin ];then
	echo -n "backup the bootloader ->  bootloader-backup.bin ... "
	dd if=/dev/$DST_NAME of=bootloader-backup.bin bs=1M count=4
	sync
	echo "done"
	echo
fi

# swapoff -a
swapoff -a

# umount all other mount points
MOUNTS=$(lsblk -l -o MOUNTPOINT)
for mnt in $MOUNTS;do
	if [ "$mnt" == "MOUNTPOINT" ];then
		continue
	fi
	if [ "$mnt" == "" ];then
		continue
	fi
	if [ "$mnt" == "/" ];then
		continue
	fi
	if [ "$mnt" == "/boot" ];then
		continue
	fi
	if [ "$mnt" == "[SWAP]" ];then
		echo "swapoff -a"
		swapoff -a
		continue
	fi
	echo "umount -f $mnt"
	umount -f $mnt
	if [ $? -ne 0 ];then
		echo "$mnt can not be umount, update abort"
		exit 1
	fi

	sleep 1
	# force umount again
	umount -f $mnt 2>/dev/null
done

# fix wifi macaddr
if [ -x /usr/bin/fix_wifi_macaddr.sh ];then
	/usr/bin/fix_wifi_macaddr.sh
fi

# Mount old rootfs
ROOTFS_FSTYPE=$(lsblk -l -o PATH,FSTYPE | grep "/dev/${DST_NAME}p2" | awk '{print $2}')
mkdir -p /mnt/${DST_NAME}p2
echo "wait for root partition mounted ... "
max_try=10
i=1
while [ $i -le $max_try ]; do
	case $ROOTFS_FSTYPE in
		ext4) 	mount -t ext4 /dev/${DST_NAME}p2 /mnt/${DST_NAME}p2 2>/dev/null
			;;
	 	btrfs)	mount -t btrfs -o compress=zstd /dev/${DST_NAME}p2 /mnt/${DST_NAME}p2 2>/dev/null
			;;
		xfs)	mount -t xfs /dev/${DST_NAME}p2 /mnt/${DST_NAME}p2 2>/dev/null
			;;
	esac

	sleep 2
	mnt=$(lsblk -l -o MOUNTPOINT | grep "/mnt/${DST_NAME}p2")
	if [ "$mnt" == "" ];then
		if [ $i -lt $max_try ];then
			echo "can not mount emmc root partition, try again ..."
			i=$((i+1))
			continue
		else
			echo "can not mount emmc root partition, abort!"
			exit 1
		fi
	else
		echo "mount ok"
		break
	fi
done

# check old version
echo "check the old version ..."
cd /mnt/${DST_NAME}p2
if [ -f ./etc/openwrt_release -a -f ./etc/armbian-release ];then
	echo "ok"
else	
	echo "the old system can not update, please use the inst-to-emmc.sh to install"
	exit 1
fi

BACKUP_LIST=$(/usr/sbin/flippy -p)
if [ $BR_FLAG -eq 1 ];then
    # backup files
    echo -n "backup files ... " 
    eval tar czf /tmp/backup.tar.gz "${BACKUP_LIST}" 2>/dev/null
    if [ -d ./usr/bin/AdGuardHome ];then
	    (cd ./usr/bin && tar czf /tmp/AdGuardHome_backup.tar.gz AdGuardHome)
    fi
    cp -fv /tmp/backup.tar.gz /boot/openwrt-backup-$(date +%Y%m%d).tar.gz
    OLD_RELEASE=$(grep DISTRIB_REVISION ./etc/openwrt_release | awk -F "'" '{print $2}'|awk -F 'R' '{print $2}' | awk -F '.' '{printf("%02d%02d%02d\n", $1,$2,$3)}')
    echo "ok"
fi

# umount old rootfs
echo -n "umount the old rootfs ... "
cd /mnt
umount -f /mnt/${DST_NAME}p2
if [ $? -ne 0 ];then
	echo "can't umount old emmc rootfs, update failed!"
	exit 1
else
	echo "ok"
fi

# Format rootfs
echo "format emmc new rootfs partition to btrfs ... "
ROOTFS_UUID=$(/usr/bin/uuidgen)
mkfs.btrfs -f -U ${ROOTFS_UUID} -L EMMC_ROOTFS -m single /dev/${DST_NAME}p2
if [ $? -ne 0 ];then
	echo "can't format new emmc rootfs, update failed! please try again!"
	echo "or inst-to-emmc.sh to repair!"
	exit 1
else
	echo "format rootfs ok"
	mkdir -p /mnt/${DST_NAME}p2
	sleep 2
	# force umount again
	umount -f /mnt/${DST_NAME}p2 2>/dev/null
fi

# mount new rootfs
echo "wait for the new rootfs partition mounted ... "
i=1
max_try=10
while [ $i -le $max_try ]; do
	mount -t btrfs -o compress=zstd /dev/${DST_NAME}p2 /mnt/${DST_NAME}p2 2>/dev/null
	sleep 2
	mnt=$(lsblk -l -o MOUNTPOINT | grep "/mnt/${DST_NAME}p2")
	if [ "$mnt" == "" ];then
		if [ $i -lt $max_try ];then
			echo "can not mount the rootfs partition, try again ..."
			i=$((i+1))
			continue
		else
			echo "mount new emmc rootfs failed, please run inst-to-emmc.sh to repair!"
			exit 1
		fi
	else
		echo "mount ok"
		break
	fi
done

echo -n "make new dirs ... "
cd /mnt/${DST_NAME}p2
mkdir -p .reserved bin boot dev etc lib opt mnt overlay proc rom root run sbin sys tmp usr www
ln -sf lib/ lib64
ln -sf tmp/ var
echo "done"
echo
		
echo "copy data ... "
cd /mnt/${DST_NAME}p2
COPY_SRC="root etc bin sbin lib opt usr www"
for src in $COPY_SRC;do
	echo -n "rm old $src ..."
	rm -rf $src
	echo "done"
	echo -n "copy new $src ... "
	(cd / && tar cf - $src) | tar mxf -
	echo "done"
	echo
done
sync

# copy others ...
echo -n "copy other files ... "
mount /dev/${DST_NAME}p3 /mnt/${DST_NAME}p3
cd /mnt/${DST_NAME}p2
[ -d /mnt/${DST_NAME}p3/docker ] || mkdir -p /mnt/${DST_NAME}p3/docker
rm -rf opt/docker && ln -sf /mnt/${DST_NAME}p3/docker/ opt/docker

if [ -f ./etc/config/AdGuardHome ];then
	mkdir -p /mnt/${DST_NAME}p3/AdGuardHome /mnt/${DST_NAME}p3/AdGuardHome/data
	if [ -f /tmp/AdGuardHome_backup.tar.gz ];then
		(cd /mnt/${DST_NAME}p3 && tar xzf /tmp/AdGuardHome_backup.tar.gz && rm -f /tmp/AdGuardHome_backup.tar.gz)
	fi
	if [ -d ./usr/bin/AdGuardHome ];then
		rm -rf ./usr/bin/AdGuardHome
	fi
	ln -sf /mnt/${DST_NAME}p3/AdGuardHome /mnt/${DST_NAME}p2/usr/bin/AdGuardHome
fi

sync
umount /mnt/${DST_NAME}p3
echo "done"
echo


if [ $BR_FLAG -eq 1 ];then
    echo -n "restore backup files ..."
    cd /mnt/${DST_NAME}p2
    NEW_RELEASE=$(grep DISTRIB_REVISION ./etc/openwrt_release|awk -F "'" '{print $2}'|awk -F 'R' '{print $2}'|awk -F '.' '{printf("%02d%02d%02d\n", $1,$2,$3)}')
    if [ ${OLD_RELEASE} -le 200311 ] && [ ${NEW_RELEASE} -ge 200319 ];then
	    mv ./etc/config/shadowsocksr ./etc/config/shadowsocksr.${NEW_RELEASE}
    fi
    mv ./etc/config/qbittorrent ./etc/config/qbittorrent.orig
    tar xzf /tmp/backup.tar.gz 2>/dev/null
    if grep 'config qbittorrent' ./etc/config/qbittorrent; then
        rm -f ./etc/config/qbittorrent.orig
    else
	mv ./etc/config/qbittorrent.orig ./etc/config/qbittorrent
    fi
    if [ ${OLD_RELEASE} -le 200311 ] && [ ${NEW_RELEASE} -ge 200319 ];then
	    mv ./etc/config/shadowsocksr ./etc/config/shadowsocksr.${OLD_RELEASE}
	    mv ./etc/config/shadowsocksr.${NEW_RELEASE} ./etc/config/shadowsocksr
    fi
    sed -e "s/option wan_mode 'false'/option wan_mode 'true'/" -i ./etc/config/dockerman 2>/dev/null
    sed -e 's/config setting/config verysync/' -i ./etc/config/verysync
    echo "done"
    echo
fi
		
echo -n "Edit config files ... "

cd /mnt/${DST_NAME}p2/root
rm -rf inst-to-emmc.sh update-to-emmc.sh

cd /mnt/${DST_NAME}p2/etc/rc.d
ln -sf ../init.d/dockerd S99dockerd

cd /mnt/${DST_NAME}p2/etc
cat > fstab <<EOF
UUID=${ROOTFS_UUID} / btrfs compress=zstd 0 1
LABEL=EMMC_BOOT /boot vfat defaults 0 2
#tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF
sed -e 's/ttyAMA0/ttyAML0/' -i inittab
sed -e 's/ttyS0/tty0/' -i inittab
sss=$(date +%s)
ddd=$((sss/86400))
sed -e "s/:0:0:99999:7:::/:${ddd}:0:99999:7:::/" -i shadow
if [ `grep "sshd:x:22:22" passwd | wc -l` -eq 0 ];then
    echo "sshd:x:22:22:sshd:/var/run/sshd:/bin/false" >> passwd
    echo "sshd:x:22:sshd" >> group
    echo "sshd:x:${ddd}:0:99999:7:::" >> shadow
fi

cd /mnt/${DST_NAME}p2/etc/config
cat > fstab <<EOF
config global
	option anon_swap '0'
	option anon_mount '1'
	option auto_swap '0'
	option auto_mount '1'
	option delay_root '5'
	option check_fs '0'

config mount
	option target '/overlay'
	option uuid '${ROOTFS_UUID}'
	option enabled '1'
	option enabled_fsck '1'
        option fstype 'btrfs'
        option options 'compress=zstd'

config mount
	option target '/boot'
	option label 'EMMC_BOOT'
	option enabled '1'
	option enabled_fsck '0'
        option fstype 'vfat'
		
EOF

# 2021.04.01添加
# 强制锁定fstab,防止用户擅自修改挂载点
chattr +ia fstab

cd /mnt/${DST_NAME}p2/etc
rm -f bench.log
cat >> crontabs/root << EOF
17 3 * * * /etc/coremark.sh
EOF
echo "edit done"
echo
	
cd /mnt/${DST_NAME}p2
if [ -x ./usr/sbin/balethirq.pl ];then
    if grep "balethirq.pl" "./etc/rc.local";then
	echo "balance irq is enabled"
    else
	echo "enable balance irq"
        sed -e "/exit/i\/usr/sbin/balethirq.pl" -i ./etc/rc.local
    fi
fi

if [ $BR_FLAG -eq 1 ];then
    if [ -x ./bin/bash ] && [ -f ./etc/profile.d/30-sysinfo.sh ];then
        sed -e 's/\/bin\/ash/\/bin\/bash/' -i ./etc/passwd
    fi
    cp /etc/config/luci ./etc/config/
    sync
fi

eval tar czf .reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null
sync
cd /
umount -f /mnt/${DST_NAME}p2
echo "copy rootfs done"
echo 

# format boot
echo "format new boot partition to vfat ..."
mkfs.fat -n EMMC_BOOT -F 32 /dev/${DST_NAME}p1 2>/dev/null
if [ $? -eq 0 ];then
	echo "format boot ok"
	mkdir -p /mnt/${DST_NAME}p1
	sleep 2
	umount -f /mnt/${DST_NAME}p1 2>/dev/null
fi

# mount boot
echo "wait for boot partition mounted ... "
i=1
max_try=10
while [ $i -le $max_try ]; do
	mount -t vfat /dev/${DST_NAME}p1 /mnt/${DST_NAME}p1 2>/dev/null
	sleep 2
	mnt=$(lsblk -l -o MOUNTPOINT | grep "/mnt/${DST_NAME}p1")
	if [ "$mnt" == "" ];then
		if [ $i -lt $max_try ];then
			echo "can not mount boot partition, try again ..."
			i=$((i+1))
			continue
		else
			echo "mount new emmc rootfs failed, please run inst-to-emmc.sh to repair!"
			exit 1
		fi
	else
		echo "mount ok"
		break
	fi
done

# copy boot contents
cd /mnt/${DST_NAME}p1
echo -n "rm old boot ..."
rm -rf *
echo "done"
echo

echo -n "copy new boot ..."
rm -rf /boot/'System Volume Information/'
(cd /boot && tar cf - .) | tar mxf -
sync
echo "done"
echo

echo -n "Write uEnv.txt ... "
cd /mnt/${DST_NAME}p1
lines=$(wc -l < /boot/uEnv.txt)
lines=$((lines-1))
head -n $lines /boot/uEnv.txt > uEnv.txt
cat >> uEnv.txt <<EOF
APPEND=root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

rm -f s905_autoscript* aml_autoscript*
sync
echo "done."
echo

cd /
umount -f /mnt/${DST_NAME}p1
echo "copy boot done"
echo 

echo "Update done, please reboot!"
