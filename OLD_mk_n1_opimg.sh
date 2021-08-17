#!/bin/bash

WORK_DIR="${PWD}/tmp"
if [ ! -d ${WORK_DIR} ];then
	mkdir -p ${WORK_DIR}
fi

# 源镜像文件
##########################################################################
OPENWRT_VER="R21.2.1"
#KERNEL_VERSION="5.4.93-flippy-52+o"
#KERNEL_VERSION="5.9.16-flippy-51+"
KERNEL_VERSION="5.10.15-flippy-53+"

SOC="s905d"
BOARD="n1"
SUBVER=$1
# Armbian
LNX_IMG="/opt/imgs/Armbian_20.10_Aml-s9xxx_buster_${KERNEL_VERSION}.img"

# +o OR + flag
if echo $KERNEL_VERSION | grep -E '*\+$';then
    SFE_FLAG=1
    FLOWOFFLOAD_FLAG=0
else
    SFE_FLAG=0
    FLOWOFFLOAD_FLAG=1
fi

# Openwrt 
OP_ROOT_TGZ="openwrt-armvirt-64-default-rootfs.tar.gz"
OPWRT_ROOTFS_GZ="${PWD}/${OP_ROOT_TGZ}"
if [ $SFE_FLAG -eq 1 ];then
    if [ -f "${PWD}/sfe/${OP_ROOT_TGZ}" ];then
        OPWRT_ROOTFS_GZ="${PWD}/sfe/${OP_ROOT_TGZ}"
    fi
elif [ ${FLOWOFFLOAD_FLAG} -eq 1 ];then
    if [ -f "${PWD}/flowoffload/${OP_ROOT_TGZ}" ];then
        OPWRT_ROOTFS_GZ="${PWD}/flowoffload/${OP_ROOT_TGZ}"
    fi
fi
echo "Use $OPWRT_ROOTFS_GZ as openwrt rootfs!"

# not used
# BOOT_TGZ="/opt/kernel/boot-${KERNEL_VERSION}.tar.gz"
# MODULES_TGZ="/opt/kernel/modules-${KERNEL_VERSION}.tar.gz"
###########################################################################

# 目标镜像文件
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"

# 可选参数：是否替换n1的dtb文件 y:替换 n:不替换
REPLACE_DTB="n"
DTB_FILE="${PWD}/files/meson-gxl-s905d-phicomm-n1.dtb"

# 补丁和脚本
###########################################################################
REGULATORY_DB="${PWD}/files/regulatory.db.tar.gz"
KMOD="${PWD}/files/kmod"
KMOD_BLACKLIST="${PWD}/files/kmod_blacklist"
INST_SCRIPT="${PWD}/files/inst-to-emmc.sh"
UPDATE_SCRIPT="${PWD}/files/update-to-emmc.sh"
MAC_SCRIPT1="${PWD}/files/fix_wifi_macaddr.sh"
MAC_SCRIPT2="${PWD}/files/find_macaddr.pl"
MAC_SCRIPT3="${PWD}/files/inc_macaddr.pl"
CPUSTAT_SCRIPT="${PWD}/files/cpustat"
CPUSTAT_SCRIPT_PY="${PWD}/files/cpustat.py"
CPUSTAT_PATCH="${PWD}/files/luci-admin-status-index-html.patch"
GETCPU_SCRIPT="${PWD}/files/getcpu"
BTLD_BIN="${PWD}/files/u-boot-2015-phicomm-n1.bin"
TTYD="${PWD}/files/ttyd"
FLIPPY="${PWD}/files/flippy"
BANNER="${PWD}/files/banner"
DAEMON_JSON="${PWD}/files/s905d/daemon.json"

# 20200314 add
FMW_HOME="${PWD}/files/firmware"
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

# 20200404 add
SND_MOD="${PWD}/files/snd-meson-gx"

# 20200709 add
COREMARK="${PWD}/files/coremark.sh"

# 20200930 add
INST_SCRIPT_S905X3="${PWD}/files/inst-s905x3-to-emmc.sh"
UPDATE_SCRIPT_S905X3="${PWD}/files/update-s905x3-to-emmc.sh"

# 20201024 add
BAL_ETH_IRQ="${PWD}/files/balethirq.pl"
# 20201026 add
FIX_CPU_FREQ="${PWD}/files/fixcpufreq.pl"
SYSFIXTIME_PATCH="${PWD}/files/sysfixtime.patch"

# 20201128 add
SSL_CNF_PATCH="${PWD}/files/openssl_engine.patch"
# 20201212 add
BAL_CONFIG="${PWD}/files/s905x/balance_irq"
###########################################################################

# 检查环境
if [ $(id -u) -ne 0 ];then
	echo "这个脚本需要用root用户来执行，你好象不是root吧？"
	exit 1
fi

if [ ! -f "$LNX_IMG" ];then
	echo "Armbian镜像: ${LNX_IMG} 不存在, 请检查!"
	exit 1
fi

if [ ! -f "$OPWRT_ROOTFS_GZ" ];then
	echo "Armbian镜像: ${OPWRT_ROOTFS_GZ} 不存在, 请检查!"
	exit 1
fi

if mkfs.btrfs -V >/dev/null;then
	echo "check mkfs.btrfs ok"
else
	echo "mkfs.btrfs 程序不存在，请安装 btrfsprogs"
	exit 1
fi

if mkfs.vfat --help 1>/dev/nul 2>&1;then
	echo "check mkfs.vfat ok"
else
	echo "mkfs.vfat 程序不存在，请安装 dosfstools"
	exit 1
fi

if uuidgen>/dev/null;then
	echo "check uuidgen ok"
else
	echo "uuidgen 程序不存在，请安装 uuid-runtime"
	exit 1
fi

if losetup -V >/dev/null;then
	echo "check losetup ok"
else
	echo "losetup 程序不存在，请安装 mount"
	exit 1
fi

if lsblk --version >/dev/null 2>&1;then
	echo "check lsblk ok"
else
	echo "lsblk 程序不存在，请安装 util-linux"
	exit 1
fi

# work dir
cd $WORK_DIR
TEMP_DIR=$(mktemp -p $WORK_DIR)
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR
echo $TEMP_DIR

# temp dir
cd $TEMP_DIR
LINUX_BOOT=armbian_boot
LINUX_ROOT=armbian_root
mkdir $LINUX_BOOT $LINUX_ROOT

# mount & tar xf
echo "挂载 Armbian 镜像 ... "
losetup -D
losetup -f -P $LNX_IMG
BLK_DEV=$(losetup | grep "$LNX_IMG" | head -n 1 | gawk '{print $1}')
mount -o ro ${BLK_DEV}p1 $LINUX_BOOT
mount -o ro ${BLK_DEV}p2 $LINUX_ROOT

# mk tgt_img
echo "创建空白的目标镜像文件 ..."
SKIP_MB=4
BOOT_MB=128
ROOTFS_MB=512
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB))
echo $SIZE

dd if=/dev/zero of=$TGT_IMG bs=1M count=$SIZE
losetup -f -P $TGT_IMG
TGT_DEV=$(losetup | grep "$TGT_IMG" | gawk '{print $1}')

echo "创建磁盘分区和文件系统 ..."
parted -s $TGT_DEV mklabel msdos 2>/dev/null
BEGIN=$((SKIP_MB * 1024 * 1024))
END=$(( BOOT_MB * 1024 * 1024 + BEGIN -1))
parted -s $TGT_DEV mkpart primary fat32 ${BEGIN}b ${END}b 2>/dev/null
BEGIN=$((END + 1))
END=$((ROOTFS_MB * 1024 * 1024 + BEGIN -1))
parted -s $TGT_DEV mkpart primary btrfs ${BEGIN}b 100% 2>/dev/null
parted -s $TGT_DEV print 2>/dev/null
mkfs.vfat -n BOOT ${TGT_DEV}p1
ROOTFS_UUID=$(uuidgen)
echo "ROOTFS_UUID = $ROOTFS_UUID"
mkfs.btrfs -U ${ROOTFS_UUID} -L ROOTFS -m single ${TGT_DEV}p2

echo "挂载目标设备 ..."
TGT_BOOT=${TEMP_DIR}/tgt_boot
TGT_ROOT=${TEMP_DIR}/tgt_root
mkdir $TGT_BOOT $TGT_ROOT
mount -t vfat ${TGT_DEV}p1 $TGT_BOOT
mount -t btrfs -o compress=zstd ${TGT_DEV}p2 $TGT_ROOT

# extract boot
echo "boot 文件解包 ... "
cd $TEMP_DIR/$LINUX_BOOT 
#if [ -f "${BOOT_TGZ}" ];then
#	( cd $TGT_BOOT; tar xvzf "${BOOT_TGZ}" )
#else
	tar cf - . | (cd $TGT_BOOT; tar xf - )
#fi

echo "openwrt 根文件系统解包 ... "
(
  cd $TGT_ROOT && \
	  tar xzf $OPWRT_ROOTFS_GZ && \
	  rm -rf ./lib/firmware/* ./lib/modules/* && \
	  mkdir -p .reserved boot rom proc sys run
)

echo "Armbian 根文件系统解包 ... "
cd $TEMP_DIR/$LINUX_ROOT && \
	tar cf - ./etc/armbian* ./etc/default/armbian* ./etc/default/cpufreq* ./lib/init ./lib/lsb ./lib/firmware ./usr/lib/armbian | (cd ${TGT_ROOT}; tar xf -)

echo "内核模块解包 ... "
cd $TEMP_DIR/$LINUX_ROOT
#if [ -f "${MODULES_TGZ}" ];then
#	(cd ${TGT_ROOT}/lib/modules; tar xvzf "${MODULES_TGZ}")
#else
	tar cf - ./lib/modules | ( cd ${TGT_ROOT}; tar xf - )
#fi

while :;do
	lsblk -l -o NAME,PATH,UUID 
	BOOT_UUID=$(lsblk -l -o NAME,PATH,UUID | grep "${TGT_DEV}p1" | awk '{print $3}')
	#ROOTFS_UUID=$(lsblk -l -o NAME,PATH,UUID | grep "${TGT_DEV}p2" | awk '{print $3}')
	echo "BOOT_UUID is $BOOT_UUID"
	echo "ROOTFS_UUID is $ROOTFS_UUID"
	if [ "$ROOTFS_UUID" != "" ];then
		break
	fi
	sleep 1
done

echo "修改引导分区相关配置 ... "
# modify boot
cd $TGT_BOOT
rm -f uEnv.ini
cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

# 下列 dtb，用到哪个就把哪个的#删除，其它的则加上 # 在行首
# 用于斐讯 Phicomm N1 , 可写入EMMC
FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1.dtb
# 用于斐讯 Phicomm N1 (thresh), 可写入EMMC
#FDT=/dtb/amlogic/meson-gxl-s905d-phicomm-n1-thresh.dtb

# 用于章鱼星球 (S912), 可写入EMMC
#FDT=/dtb/amlogic/meson-gxm-octopus-planet.dtb

APPEND=root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

# 替换dtb文件
[ "$REPLACE_DTB" == "y" ] && [ -f "$DTB_FILE" ] && cp "$DTB_FILE" ./dtb/amlogic/

echo "uEnv.txt --->"
cat uEnv.txt

# 5.10以后的内核，需要增加u-boot重载
if [ -f u-boot-p212.bin ];then
	cp -fv u-boot-p212.bin u-boot.ext
	cp -fv u-boot-p212.bin u-boot.emmc
fi

echo "修改根文件系统相关配置 ... "
# modify root
cd $TGT_ROOT

[ -f $BTLD_BIN ] && cp $BTLD_BIN root/
[ -f $INST_SCRIPT ] && cp $INST_SCRIPT root/
[ -f $UPDATE_SCRIPT ] && cp $UPDATE_SCRIPT root/
[ -f $MAC_SCRIPT1 ] && cp $MAC_SCRIPT1 usr/bin/
[ -f $MAC_SCRIPT2 ] && cp $MAC_SCRIPT2 usr/bin/
[ -f $MAC_SCRIPT3 ] && cp $MAC_SCRIPT3 usr/bin/
[ -f $DAEMON_JSON ] && mkdir -p "etc/docker" && cp $DAEMON_JSON "etc/docker/daemon.json"
[ -f $COREMARK ] && [ -f "etc/coremark.sh" ] && cp -f $COREMARK "etc/coremark.sh" && chmod 755 "etc/coremark.sh"
if [ -x usr/bin/perl ];then
	[ -f $CPUSTAT_SCRIPT ] && cp $CPUSTAT_SCRIPT usr/bin/
	[ -f $GETCPU_SCRIPT ] && cp $GETCPU_SCRIPT bin/
else
	[ -f $CPUSTAT_SCRIPT_PY ] && cp $CPUSTAT_SCRIPT_PY usr/bin/cpustat
fi
[ -f $TTYD ] && cp $TTYD etc/init.d/
[ -f $FLIPPY ] && cp $FLIPPY usr/sbin/
if [ -f $BANNER ];then
    cp -f $BANNER etc/banner
    echo " Base on OpenWrt ${OPENWRT_VER} by lean & lienol" >> etc/banner
    echo " Kernel ${KERNEL_VERSION}" >> etc/banner
    TODAY=$(date +%Y-%m-%d)
    echo " Packaged by flippy on $TODAY" >> etc/banner
    echo >> etc/banner
fi

if [ -f $BAL_ETH_IRQ ];then
    cp -v $BAL_ETH_IRQ usr/sbin
    chmod 755 usr/sbin/balethirq.pl
    sed -e "/exit/i\/usr/sbin/balethirq.pl" -i etc/rc.local
    [ -f ${BAL_CONFIG} ] && cp -v ${BAL_CONFIG} etc/config/
fi

if [ -f $FIX_CPU_FREQ ];then
    cp -v $FIX_CPU_FREQ usr/sbin
    chmod 755 usr/sbin/fixcpufreq.pl
fi
if [ -f $SYSFIXTIME_PATCH ];then
    patch -p1 < $SYSFIXTIME_PATCH
fi
if [ -f $SSL_CNF_PATCH ];then
    patch -p1 < $SSL_CNF_PATCH
fi

[ -d ${FMW_HOME} ] && cp -a ${FMW_HOME}/* lib/firmware/
[ -f ${SYSCTL_CUSTOM_CONF} ] && cp ${SYSCTL_CUSTOM_CONF} etc/sysctl.d/
[ -d boot ] || mkdir -p boot
[ -d overlay ] || mkdir -p overlay
[ -d rom ] || mkdir -p rom
[ -d sys ] || mkdir -p sys
[ -d proc ] || mkdir -p proc
[ -d run ] || mkdir -p run
sed -e 's/ttyAMA0/ttyAML0/' -i ./etc/inittab
sed -e 's/ttyS0/tty0/' -i ./etc/inittab
sed -e 's/\/opt/\/etc/' -i ./etc/config/qbittorrent
sed -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" -i ./etc/ssh/sshd_config 2>/dev/null
sss=$(date +%s)
ddd=$((sss/86400))
sed -e "s/:0:0:99999:7:::/:${ddd}:0:99999:7:::/" -i ./etc/shadow
sed -e 's/root::/root:$1$NA6OM0Li$99nh752vw4oe7A.gkm2xk1:/' -i ./etc/shadow

# for collectd
#[ -f ./etc/ppp/options-opkg ] && mv ./etc/ppp/options-opkg ./etc/ppp/options

# for cifsd
[ -f ./etc/init.d/cifsd ] && rm -f ./etc/rc.d/S98samba4
# for smbd
[ -f ./etc/init.d/smbd ] && rm -f ./etc/rc.d/S98samba4
# for ksmbd
[ -f ./etc/init.d/ksmbd ] && rm -f ./etc/rc.d/S98samba4 && sed -e 's/modprobe ksmbd/sleep 1 \&\& modprobe ksmbd/' -i ./etc/init.d/ksmbd
# for samba4 enable smbv1 protocol
[ -f ./etc/config/samba4 ] && \
	sed -e 's/services/nas/g' -i ./usr/lib/lua/luci/controller/samba4.lua && \
	[ -f ${SMB4_PATCH} ] && \
	patch -p1 < ${SMB4_PATCH}
# for nfs server
if [ -f ./etc/init.d/nfsd ];then
    echo "/mnt/mmcblk2p3 *(rw,sync,no_root_squash,insecure,no_subtree_check)" > ./etc/exports
    cat > ./etc/config/nfs <<EOF
config share
	option clients '*'
	option enabled '1'
	option options 'rw,sync,no_root_squash,insecure,no_subtree_check'
	option path '/mnt/mmcblk2p3'
EOF
fi

chmod 755 ./etc/init.d/*

sed -e "s/START=25/START=99/" -i ./etc/init.d/dockerd 2>/dev/null
sed -e "s/START=90/START=99/" -i ./etc/init.d/dockerd 2>/dev/null
sed -e "s/option wan_mode 'false'/option wan_mode 'true'/" -i ./etc/config/dockerman 2>/dev/null
mv -f ./etc/rc.d/S??dockerd ./etc/rc.d/S99dockerd 2>/dev/null
rm -f ./etc/rc.d/S80nginx 2>/dev/null

cat > ./etc/fstab <<EOF
UUID=${ROOTFS_UUID} / btrfs compress=zstd 0 1
LABEL=BOOT /boot vfat defaults 0 2
#tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF
echo "/etc/fstab --->"
cat ./etc/fstab

cat > ./etc/config/fstab <<EOF
config global
        option anon_swap '0'
        option auto_swap '0'
        option anon_mount '0'
        option auto_mount '1'
        option delay_root '5'
        option check_fs '0'

config mount
        option target '/overlay'
        option uuid '${ROOTFS_UUID}'
        option enabled '1'
        option enabled_fsck '1'
	option options 'compress=zstd'
	option fstype 'btrfs'

config mount
        option target '/boot'
        option label 'BOOT'
        option enabled '1'
        option enabled_fsck '1'
	option fstype 'vfat'
EOF
echo "/etc/config/fstab --->"
cat ./etc/config/fstab

mkdir -p ./etc/modprobe.d
cat > ./etc/modprobe.d/99-local.conf <<EOF
blacklist meson_gxbb_wdt
blacklist snd_soc_meson_aiu_i2s
alias brnf br_netfilter
alias pwm pwm_meson
alias wifi brcmfmac
EOF

# echo br_netfilter > ./etc/modules.d/br_netfilter
echo pwm_meson > ./etc/modules.d/pwm_meson

mkdir ./etc/modules.d.remove
mod_blacklist=$(cat ${KMOD_BLACKLIST})
for mod in $mod_blacklist ;do
	mv -f ./etc/modules.d/${mod} ./etc/modules.d.remove/ 2>/dev/null
done
[ -f ./etc/modules.d/usb-net-asix-ax88179 ] || echo "ax88179_178a" > ./etc/modules.d/usb-net-asix-ax88179
if echo $KERNEL_VERSION | grep -E '*\+$' ;then
	echo "r8152" > ./etc/modules.d/usb-net-rtl8152
else
	echo "r8152" > ./etc/modules.d/usb-net-rtl8152
fi
[ -f ./etc/config/shairport-sync ] && [ -f ${SND_MOD} ] && cp ${SND_MOD} ./etc/modules.d/
echo "r8188eu" > ./etc/modules.d/rtl8188eu

rm -f ./etc/rc.d/S*dockerd

cd $TGT_ROOT/lib/modules/${KERNEL_VERSION}/
find . -name '*.ko' -exec ln -sf {} . \;
rm -f ntfs.ko

cd $TGT_ROOT/sbin
if [ ! -x kmod ];then
	cp $KMOD .
fi
ln -sf kmod depmod
ln -sf kmod insmod
ln -sf kmod lsmod
ln -sf kmod modinfo
ln -sf kmod modprobe
ln -sf kmod rmmod
ln -sf /usr/bin/ntfs-3g mount.ntfs

cd $TGT_ROOT/lib/firmware
mv *.hcd brcm/ 2>/dev/null
if [ -f "$REGULATORY_DB" ];then
	tar xzf "$REGULATORY_DB"
fi

cd brcm
source $TGT_ROOT/usr/lib/armbian/armbian-common
get_random_mac
sed -e "s/macaddr=b8:27:eb:74:f2:6c/macaddr=${MACADDR}/" "brcmfmac43455-sdio.txt" > "brcmfmac43455-sdio.phicomm,n1.txt"

rm -f ${TGT_ROOT}/etc/bench.log
cat >> ${TGT_ROOT}/etc/crontabs/root << EOF
17 3 * * * /etc/coremark.sh
EOF

[ -f $CPUSTAT_PATCH ] && \
cd $TGT_ROOT/usr/lib/lua/luci/view/admin_status && \
patch -p0 < ${CPUSTAT_PATCH}

# clean temp_dir
cd $TEMP_DIR
umount -f $LINUX_BOOT $LINUX_ROOT $TGT_BOOT $TGT_ROOT 

( losetup -D && cd $WORK_DIR && rm -rf $TEMP_DIR && losetup -D)
sync
echo
echo "我䖈 N1 一千遍，N1 待我如初恋！"
echo "镜像打包已完成，再见!"
