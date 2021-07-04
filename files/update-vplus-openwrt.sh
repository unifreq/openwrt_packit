#!/bin/sh

# check cmd param
if [ "$1" == "" ];then
	echo "Usage: $0 xxx.img"
	exit 1
fi

# check image file
IMG_NAME=$1
if [ ! -f "$IMG_NAME" ];then
	echo "$IMG_NAME not exists!"
	exit 1
fi

# find boot partition 
BOOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | awk '$3~/^part$/ && $5 ~ /^\/boot$/ {print $0}')
if [ "${BOOT_PART_MSG}" == "" ];then
	echo "The boot partition is not exists or not mounted, so it cannot be upgraded with this script!"
	exit 1
fi

BR_FLAG=1
echo -ne "Do you want to backup old config files and restore to new system? y/n [y]\b\b"
read yn
case $yn in
    n*|N*) BR_FLAG=0;;
esac

BOOT_NAME=$(echo $BOOT_PART_MSG | awk '{print $1}')
BOOT_PATH=$(echo $BOOT_PART_MSG | awk '{print $2}')
BOOT_UUID=$(echo $BOOT_PART_MSG | awk '{print $4}')

# find root partition 
ROOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | awk '$3~/^part$/ && $5 ~ /^\/$/ {print $0}')
ROOT_NAME=$(echo $ROOT_PART_MSG | awk '{print $1}')
ROOT_PATH=$(echo $ROOT_PART_MSG | awk '{print $2}')
ROOT_UUID=$(echo $ROOT_PART_MSG | awk '{print $4}')
case $ROOT_NAME in 
  mmcblk0p2) NEW_ROOT_NAME=mmcblk0p3
	     NEW_ROOT_LABEL=EMMC_ROOTFS2
	     ;;
  mmcblk0p3) NEW_ROOT_NAME=mmcblk0p2
	     NEW_ROOT_LABEL=EMMC_ROOTFS1
	     ;;
          *) echo "The root partition location is invalid, so it cannot be upgraded with this script!"
             exit 1
             ;;
esac

# find new root partition
NEW_ROOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | grep "${NEW_ROOT_NAME}" | awk '$3 ~ /^part$/ && $5 !~ /^\/$/ && $5 !~ /^\/boot$/ {print $0}')
if [ "${NEW_ROOT_PART_MSG}" == "" ];then
	echo "The new root partition is not exists, so it cannot be upgraded with this script!"
	exit 1
fi
NEW_ROOT_NAME=$(echo $NEW_ROOT_PART_MSG | awk '{print $1}')
NEW_ROOT_PATH=$(echo $NEW_ROOT_PART_MSG | awk '{print $2}')
NEW_ROOT_UUID=$(echo $NEW_ROOT_PART_MSG | awk '{print $4}')
NEW_ROOT_MP=$(echo $NEW_ROOT_PART_MSG | awk '{print $5}')

# losetup
losetup -f -P $IMG_NAME
if [ $? -eq 0 ];then
	LOOP_DEV=$(losetup | grep "$IMG_NAME" | awk '{print $1}')
	if [ "$LOOP_DEV" == "" ];then
		echo "loop device not found!"
		exit 1
	fi
else
	echo "losetup $IMG_FILE failed!"
	exit 1
fi
WAIT=3
echo -n "The loopdev is $LOOP_DEV, wait ${WAIT} seconds "
while [ $WAIT -ge 1 ];do
	echo -n "."
	sleep 1
	WAIT=$(( WAIT - 1 ))
done
echo

# umount loop devices (openwrt will auto mount some partition)
MOUNTED_DEVS=$(lsblk -l -o NAME,PATH,MOUNTPOINT | grep "$LOOP_DEV" | awk '$3 !~ /^$/ {print $2}')
for dev in $MOUNTED_DEVS;do
	while : ;do
		echo -n "umount $dev ... "
		umount -f $dev
		sleep 1
		mnt=$(lsblk -l -o NAME,PATH,MOUNTPOINT | grep "$dev" | awk '$3 !~ /^$/ {print $2}')
		if [ "$mnt" == "" ];then
			echo "ok"
			break
		else 
			echo "try again ..."
		fi
	done
done

# mount src part
WORK_DIR=$PWD
P1=${WORK_DIR}/boot
P2=${WORK_DIR}/root
mkdir -p $P1 $P2
echo -n "mount ${LOOP_DEV}p1 -> ${P1} ... "
mount -t vfat -o ro ${LOOP_DEV}p1 ${P1}
if [ $? -ne 0 ];then
	echo "mount failed"
	losetup -D
	exit 1
else 
	echo "ok"
fi	

echo -n "mount ${LOOP_DEV}p2 -> ${P2} ... "
mount -t btrfs -o ro,compress=zstd ${LOOP_DEV}p2 ${P2}
if [ $? -ne 0 ];then
	echo "mount failed"
	umount -f ${P1}
	losetup -D
	exit 1
else
	echo "ok"
fi	

#format NEW_ROOT
echo "umount ${NEW_ROOT_MP}"
umount -f "${NEW_ROOT_MP}"
if [ $? -ne 0 ];then
	echo "umount failed, please reboot and try again!"
	umount -f ${P1}
	umount -f ${P2}
	losetup -D
	exit 1
fi

echo "format ${NEW_ROOT_PATH}"
NEW_ROOT_UUID=$(uuidgen)
mkfs.btrfs -f -U ${NEW_ROOT_UUID} -L ${NEW_ROOT_LABEL} ${NEW_ROOT_PATH}
if [ $? -ne 0 ];then
	echo "format ${NEW_ROOT_PATH} failed!"
	umount -f ${P1}
	umount -f ${P2}
	losetup -D
	exit 1
fi

echo "mount ${NEW_ROOT_PATH} to ${NEW_ROOT_MP}"
mount -t btrfs -o compress=zstd ${NEW_ROOT_PATH} ${NEW_ROOT_MP}
if [ $? -ne 0 ];then
	echo "mount ${NEW_ROOT_PATH} to ${NEW_ROOT_MP} failed!"
	umount -f ${P1}
	umount -f ${P2}
	losetup -D
	exit 1
fi

# begin copy rootfs
cd ${NEW_ROOT_MP}
echo "Start copy data from ${P2} to ${NEW_ROOT_MP} ..."
ENTRYS=$(ls)
for entry in $ENTRYS;do
	if [ "$entry" == "lost+found" ];then
		continue
	fi
	echo -n "remove old $entry ... "
	rm -rf $entry 
	if [ $? -eq 0 ];then
		echo "ok"
	else
		echo "failed"
		exit 1
	fi
done
echo

echo "create etc subvolume ..."
btrfs subvolume create etc
echo -n "make dirs ... "
mkdir -p .snapshots .reserved bin boot dev lib opt mnt overlay proc rom root run sbin sys tmp usr www
ln -sf lib/ lib64
ln -sf tmp/ var
echo "done"
echo

COPY_SRC="root etc bin sbin lib opt usr www"
echo "copy data ... "
for src in $COPY_SRC;do
	echo -n "copy $src ... "
        (cd ${P2} && tar cf - $src) | tar xf -
        sync
        echo "done"
done

SHFS="/mnt/mmcblk0p4"
echo "Modify config files ... "
rm -f "./etc/rc.local.orig" "./usr/bin/mk_newpart.sh" "./etc/part_size"
rm -f ./etc/bench.log
if [ -x ./usr/sbin/balethirq.pl ];then
    if grep "balethirq.pl" "./etc/rc.local";then
	echo "balance irq is enabled"
    else
	echo "enable balance irq"
        sed -e "/exit/i\/usr/sbin/balethirq.pl" -i ./etc/rc.local
    fi
fi
cat > ./etc/fstab <<EOF
UUID=${NEW_ROOT_UUID} / btrfs compress=zstd 0 1
LABEL=EMMC_BOOT /boot vfat defaults 0 2
#tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF

cat > ./etc/config/fstab <<EOF
config global
        option anon_swap '0'
        option anon_mount '1'
        option auto_swap '0'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'

config mount
        option target '/overlay'
        option uuid '${NEW_ROOT_UUID}'
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

echo "create the first etc snapshot -> .snapshots/etc-000"
btrfs subvolume snapshot -r etc .snapshots/etc-000

[ -d ${SHFS}/docker ] || mkdir -p ${SHFS}/docker
rm -rf opt/docker && ln -sf ${SHFS}/docker/ opt/docker

if [ -f /mnt/${NEW_ROOT_NAME}/etc/config/AdGuardHome ];then
	[ -d ${SHFS}/AdGuardHome/data ] || mkdir -p ${SHFS}/AdGuardHome/data
      	if [ ! -L /usr/bin/AdGuardHome ];then
		[ -d /usr/bin/AdGuardHome ] && \
		cp -a /usr/bin/AdGuardHome/* ${SHFS}/AdGuardHome/

	fi
	ln -sf ${SHFS}/AdGuardHome /mnt/${NEW_ROOT_NAME}/usr/bin/AdGuardHome
fi

BOOTLOADER="./lib/u-boot/u-boot-sunxi-with-spl.bin"
if [ -f ${BOOTLOADER} ];then
	echo "update u-boot ... "
	# erase from 8kb to 4mb
	dd if=/dev/zero of=/dev/mmcblk0 bs=1024 seek=8 count=4088 conv=fsync
	# write u-boot
	dd if=${BOOTLOADER} of=/dev/mmcblk0 bs=1024 seek=8 conv=fsync
	echo "done"
fi
sync
echo "copy done"
echo

BACKUP_LIST=$(${P2}/usr/sbin/flippy -p)
if [ $BR_FLAG -eq 1 ];then
    echo -n "Restore your old config files ... "
    (
      cd /
      eval tar czf ${NEW_ROOT_MP}/.reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null
    )
    tar xzf ${NEW_ROOT_MP}/.reserved/openwrt_config.tar.gz
    [ -f ./etc/config/dockerman ] &&  sed -e "s/option wan_mode 'false'/option wan_mode 'true'/" -i ./etc/config/dockerman 2>/dev/null
    [ -f ./etc/config/dockerd ] && sed -e "s/option wan_mode '0'/option wan_mode '1'/" -i ./etc/config/dockerd 2>/dev/null
    [ -f ./etc/config/verysync ] && sed -e 's/config setting/config verysync/' -i ./etc/config/verysync
    
    # 还原 fstab
    cp -f .snapshots/etc-000/fstab ./etc/fstab
    cp -f .snapshots/etc-000/config/fstab ./etc/config/fstab
    sync
    echo "done"
    echo
fi

rm -f ./etc/bench.log
cat >> ./etc/crontabs/root << EOF
17 3 * * * /etc/coremark.sh
EOF

sed -e 's/ttyAMA0/ttyS0/' -i ./etc/inittab
sss=$(date +%s)
ddd=$((sss/86400))
sed -e "s/:0:0:99999:7:::/:${ddd}:0:99999:7:::/" -i ./etc/shadow
if [ `grep "sshd:x:22:22" ./etc/passwd | wc -l` -eq 0 ];then
    echo "sshd:x:22:22:sshd:/var/run/sshd:/bin/false" >> ./etc/passwd
    echo "sshd:x:22:sshd" >> ./etc/group
    echo "sshd:x:${ddd}:0:99999:7:::" >> ./etc/shadow
fi

if [ $BR_FLAG -eq 1 ];then
    if [ -x ./bin/bash ] && [ -f ./etc/profile.d/30-sysinfo.sh ];then
        sed -e 's/\/bin\/ash/\/bin\/bash/' -i ./etc/passwd
    fi
    sync
    echo "done"
    echo
fi
eval tar czf .reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null

rm -f ./etc/part_size ./usr/bin/mk_newpart.sh
mv ./etc/rc.local ./etc/rc.local.orig
cat > ./etc/rc.local <<EOF
if [ ! -f /etc/rc.d/*dockerd ];then
	/etc/init.d/dockerd enable
	/etc/init.d/dockerd start
fi
opkg remove --force-removal-of-dependent-packages shairport-sync-openssl
mv /etc/rc.local.orig /etc/rc.local
exec /etc/rc.local
exit
EOF
chmod 755 ./etc/rc.local*

echo "create the second etc snapshot -> .snapshots/etc-001"
btrfs subvolume snapshot -r etc .snapshots/etc-001

# 2021.04.01添加
# 强制锁定fstab,防止用户擅自修改挂载点
# 开启了快照功能之后，不再需要锁定fstab
#chattr +ia ./etc/config/fstab

cd ${WORK_DIR}
 
echo "Start copy data from ${P1} to /boot ..."
cd /boot
echo -n "remove old boot files ..."
rm -rf *
echo "done"
echo -n "copy new boot files ... " 
(cd ${P1} && tar cf - . ) | tar xf -
sync
echo "done"
echo

echo -n "Update boot args ... "
cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

FDT=/dtb/allwinner/sun50i-h6-vplus-cloud.dtb
#FDT=/dtb/allwinner/sun50i-h6-vplus-cloud-2ghz.dtb

APPEND=root=UUID=${NEW_ROOT_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyS0,115200n8 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

sync
echo "done"
echo

cd $WORK_DIR
umount -f ${P1} ${P2}
losetup -D
rmdir ${P1} ${P2}
echo "Update done, please reboot!"
echo
