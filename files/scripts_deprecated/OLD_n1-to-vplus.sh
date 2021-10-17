#!/bin/bash

WORKDIR=$(pwd)
mkdir -p sp1 sp2 dp1 dp2

# 镜像大小,单位(MB)
SKIP=4
BOOT=160
ROOT=720

# 其它变量
OPENWRT_VER="R21.2.1"
#KERNEL_VER=5.4.97-flippy-53+o
#KERNEL_VER=5.9.16-flippy-51+
KERNEL_VER=5.10.16-flippy-53+

SOC="h6"
BOARD="vplus"

SRC=$WORKDIR/tmp/openwrt_s905d_n1_${OPENWRT_VER}_k${KERNEL_VER}.img
DST=$WORKDIR/tmp/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VER}.img
SCRIPT_DIR=$WORKDIR/files
BOOTLOADER=${SCRIPT_DIR}/vplus/u-boot-v2020.10/u-boot-sunxi-with-spl.bin

if [ ! -f $SRC ];then
	echo "没有发现 $SRC"
	exit 1
fi

echo "需要用到losetup parted mkfs.vfat mkfs.btrfs uuidgen 等命令，请自行检查，回车继续，ctrl-c退出"
read pause

losetup -D

losetup -f -P $SRC
if [ $? -ne 0 ];then
	echo "losetup ${SRC} 失败！"
	exit 1
fi
SRC_DEV=$(losetup | grep $SRC | awk '{print $1}')
echo "源镜像设备是: $SRC_DEV"

ALL=$((SKIP + BOOT + ROOT))
echo "创建 ${ALL}MB 大小的空白目标镜像 ..."
dd if=/dev/zero of=$DST bs=1M count=$ALL
echo "空白镜像创建完成"
echo 

losetup -f -P $DST
if [ $? -ne 0 ];then
	echo "losetup ${DST_DEV} 失败！"
	exit 1
fi
DST_DEV=$(losetup | grep $DST | awk '{print $1}')
echo "目标镜像设备是: $DST_DEV"

echo "创建分区 ..."
parted -s ${DST_DEV} mklabel msdos 2>/dev/null
parted -s ${DST_DEV} mkpart primary fat32 $((SKIP*1024*1024))b $(( (SKIP+BOOT)*1024*1024 -1))b 2>/dev/null
parted -s ${DST_DEV} mkpart primary ext4  $(( (SKIP+BOOT)*1024*1024 ))b $(( (SKIP+BOOT+ROOT)*1024*1024 -1 ))b 2>/dev/null
parted -s ${DST_DEV} print 2>/dev/null
echo "分区创建完成"
echo


echo "格式化 ${DST_DEV}p1 ..."
mkfs.vfat -n EMMC_BOOT ${DST_DEV}p1
echo "完成"

echo "生成btrfs分区的uuid ..."
UUID=$(uuidgen)
if [ "$UUID" == "" ];then
	echo "UUID 生成失败！"
	exit 1
fi
echo "UUID: ${UUID}"
echo "格式化 ${DST_DEV}p2 ..."
mkfs.btrfs -L EMMC_ROOTFS1 -U ${UUID} -m single ${DST_DEV}p2
echo "完成"
echo

echo "挂载源镜像 ..."
mount ${SRC_DEV}p1 sp1
if [ $? -ne 0 ];then
	echo "${SRC_DEV}p1 挂载失败！"
	exit 1
fi

mount ${SRC_DEV}p2 sp2
if [ $? -ne 0 ];then
	echo "${SRC_DEV}p2 挂载失败！"
	exit 1
fi
echo "源镜像挂载成功"
echo

echo "挂载目标镜像 ..."
mount ${DST_DEV}p1 dp1
if [ $? -ne 0 ];then
	echo "${DST_DEV}p1 挂载失败！"
	exit 1
fi

mount -t btrfs -o compress=zstd ${DST_DEV}p2 dp2
if [ $? -ne 0 ];then
	echo "${DST_DEV}p2 挂载失败！"
	exit 1
fi
echo "目标镜像挂载成功"
echo

echo "开始拷贝文件 ... "
cd $WORKDIR
echo -n "boot -> boot ... "
cd dp1  && 
(cd ../sp1 && tar cf - .) | tar xf -
echo "ok"
echo

echo -n "rootfs -> rootfs ... "
cd ../dp2 && (cd ../sp2 &&  tar cf - .) | tar xf -
echo "ok"
echo

echo "修改boot ..."
cd $WORKDIR
cd dp1
rm -f s905_autoscript* aml_autoscript* boot-emmc* emmc_autoscript* u-boot.*  boot.ini boot.cmd* boot.scr* 
rm -rf dtb/amlogic
mkdir dtb/allwinner
cp -v $SCRIPT_DIR/vplus/boot/dtb/allwinner/* dtb/allwinner/
cp -v $SCRIPT_DIR/vplus/boot/boot.cmd .
cp -v $SCRIPT_DIR/vplus/boot/boot.scr .
cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

FDT=/dtb/allwinner/sun50i-h6-vplus-cloud.dtb
#FDT=/dtb/allwinner/sun50i-h6-vplus-cloud-2ghz.dtb

APPEND=root=UUID=${UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyS0,115200n8 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF
echo "boot修改完毕"

echo "修改rootfs ..."
cd $WORKDIR
cd dp2
cat > etc/inittab <<EOF
::sysinit:/etc/init.d/rcS S boot
::shutdown:/etc/init.d/rcS K shutdown
ttyS0::askfirst:/usr/libexec/login.sh
EOF

cat > etc/fstab <<EOF
UUID=${UUID} / btrfs compress=zstd 0 1
LABEL=EMMC_BOOT /boot vfat defaults 0 2
#tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF

cat > etc/config/fstab <<EOF
config global
        option anon_swap '0'
        option auto_swap '0'
        option anon_mount '0'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'

config mount
        option target '/overlay'
        option uuid '${UUID}'
        option enabled '1'
        option enabled_fsck '1'
        option options 'compress=zstd'
        option fstype 'btrfs'

config mount
        option target '/boot'
        option label 'EMMC_BOOT'
        option enabled '1'
        option enabled_fsck '1'
        option fstype 'vfat'
EOF

cat > etc/docker/daemon.json <<EOF
{
  "bip": "172.31.0.1/24",
  "data-root": "/mnt/mmcblk0p4/docker/",
  "log-level": "warn",
  "log-driver": "json-file",
  "log-opts": {
     "max-size": "10m",
     "max-file": "5"
   },
   "registry-mirrors": [
     "https://dockerhub.azk8s.cn"
   ]
}
EOF
(cd etc/rc.d && ln -s ../init.d/dockerd S99dockerd)
(cd etc/init.d && sed -e 's/echo 1000000/#echo 10000/' -i boot)
(cd etc/modules.d && rm -f pwm_meson snd-meson-gx brcmfmac brcmutil usb-audio && echo "sunxi_wdt" > 11-watchdog)
cp ${SCRIPT_DIR}/mk_newpart.sh usr/bin/
cp ${SCRIPT_DIR}/vplus/rc.local* etc/
cp ${SCRIPT_DIR}/vplus/balance_irq etc/config/
cp ${SCRIPT_DIR}/flippy usr/sbin/
cp ${SCRIPT_DIR}/update-vplus-openwrt.sh usr/sbin/
mkdir -p lib/u-boot && cp ${BOOTLOADER} lib/u-boot/
(cd etc/modules.d && echo "xhci-sunxi" > 36-usb-xhci)
cat > etc/part_size <<EOF
$SKIP	$BOOT	$ROOT
EOF
rm -f root/*.sh root/*.bin
sync
echo "rootfs修改完毕"
echo "初始IP地址是 192.168.1.1" 
echo

cd $WORKDIR
echo "卸载文件系统 ..."
umount dp1 dp2 sp1 sp2
echo "卸载完毕"
echo


echo "写入 bootloader ..."
dd if=${BOOTLOADER} of=${DST_DEV} bs=1024 seek=8
sync
echo "写入完毕"
echo

losetup -D
echo "镜像生成完毕： $DST"
