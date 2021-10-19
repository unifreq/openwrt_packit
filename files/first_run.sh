#!/bin/bash

MYSELF=$0

function destory_myself() {
    rm -f $MYSELF /etc/part_size /tmp/fdisk.script
    mv -f /etc/rc.local.orig /etc/rc.local
}

if [ ! -f /etc/part_size ];then
    echo "/etc/part_size 不存在！"
    destory_myself
    exit 1
fi

# 找到 root 所在的分区
ROOT_PTNAME=$(df / | tail -n1 | awk '{print $1}' | awk -F '/' '{print $3}')
if [ "$ROOT_PTNAME" == "" ];then
    echo "找不到根文件系统对应的分区!"
    destory_myself
    exit 1
fi

# 找到分区所在的磁盘, 仅支持 mmcblk?p?  sd?? hd?? vd??等格式
case $ROOT_PTNAME in 
       mmcblk?p[1-4]) DISK_NAME=$(echo $ROOT_PTNAME | awk '{print substr($1, 1, length($1)-2)}');;
    [hsv]d[a-z][1-4]) DISK_NAME=$(echo $ROOT_PTNAME | awk '{print substr($1, 1, length($1)-1)}');;
                   *) echo "无法识别 $ROOT_PTNAME 的磁盘类型!"
                      destory_myself
                      exit 1
                   ;;
esac

CURRENT_PT_CNT=$(fdisk -l /dev/${DISK_NAME} | grep -A4 'Device' | grep -v 'Device' | wc -l)
if [ "$CURRENT_PT_CNT" != "2" ];then
    echo "现存分区数量不为2,放弃!"
    destory_myself
    exit 1
fi
TOTAL_SIZE=$(lsblk -l -b -o NAME,SIZE | awk "\$1 ~ /^${DISK_NAME}\$/ {print \$2}")

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

echo "Backup the partition table ... "
dd if=/dev/$DISK_NAME of=/tmp/partition.bak bs=512 count=1
sync
echo "done"

echo "fdisk starting ... "
fdisk /dev/$DISK_NAME < /tmp/fdisk.script
if [ $? -ne 0 ];then
        echo "fdisk failed, restore the backup bootloader, and abort"
        dd if=/tmp/partition.bak of=/dev/$DISK_NAME bs=512 count=1
        sync
        destory_myself
        exit 1
fi
echo "fdisk done"
echo

# mkfs
case $DISK_NAME in 
   mmcblk*) PT_PRE=${DISK_NAME}p
            LB_PRE="EMMC_"
            ;;
         *) PT_PRE=${DISK_NAME}
            LB_PRE=""
            ;;
esac
echo "create rootfs2 filesystem ... "
case $TARGET_ROOTFS2_FSTYPE in
        xfs) mkfs.xfs   -f -L "${LB_PRE}ROOTFS2" "/dev/${PT_PRE}3";;
      btrfs) mkfs.btrfs -f -L "${LB_PRE}ROOTFS2" "/dev/${PT_PRE}3";; 
          *) mkfs.ext4  -F -L "${LB_PRE}ROOTFS2" "/dev/${PT_PRE}3";;
esac
echo "done"

echo "create shared filesystem ... "
mkdir -p /mnt/${PT_PRE}4
case $TARGET_SHARED_FSTYPE in
        xfs) mkfs.xfs   -f -L "${LB_PRE}SHARED" "/dev/${PT_PRE}4"
             mount -t xfs     "/dev/${PT_PRE}4" "/mnt/${PT_PRE}4"
             ;;
      btrfs) mkfs.btrfs -f -L "${LB_PRE}SHARED" "/dev/${PT_PRE}4"
             mount -t btrfs   "/dev/${PT_PRE}4" "/mnt/${PT_PRE}4"
             ;; 
          *) mkfs.ext4  -F -L "${LB_PRE}SHARED" "/dev/${PT_PRE}4"
             mount -t ext4    "/dev/${PT_PRE}4" "/mnt/${PT_PRE}4"
             ;;
esac
echo "done"

# 新分区建立成功后, 允许在非EMMC设备上也启用docker
# init dockerd
echo "Init the dockerd configs ... "
mkdir -p "/mnt/${PT_PRE}4/docker"
rm -rf "/opt/docker"
ln -sf "/mnt/${PT_PRE}4/docker/" "/opt/docker"
cat > /etc/docker/daemon.json <<EOF
{
  "bip": "172.31.0.1/24",
  "data-root": "/mnt/${PT_PRE}4/docker/",
  "log-level": "warn",
  "log-driver": "json-file",
  "log-opts": {
     "max-size": "10m",
     "max-file": "5"
   },
  "registry-mirrors": [
     "https://docker.mirrors.ustc.edu.cn",
     "https://registry.cn-shanghai.aliyuncs.com",
     "https://hub-mirror.c.163.com"
   ]
}
EOF
echo "done"
echo -n "stop dockerd ... "
/etc/init.d/dockerd stop
echo "ok"

echo -n "disable dockerd ... "
/etc/init.d/dockerd disable
echo "ok"

echo -n "starting dockerd ... "
/etc/init.d/dockerd start
echo "ok"

echo -n "enable dockerd ... "
/etc/init.d/dockerd enable
echo "ok"

# init AdguardHome
echo "Init the Adguard config ... "
if [ -f /etc/config/AdGuardHome ];then
    mkdir -p "/mnt/${PT_PRE}4/AdGuardHome/data"
    rm -rf "/usr/bin/AdGuardHome"
    ln -sf "/mnt/${PT_PRE}4/AdGuardHome /usr/bin/AdGuardHome"
fi
sync
echo "done"
echo "clean ... "
destory_myself
echo "done"
echo "The end."
