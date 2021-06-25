#!/bin/bash

WORK_DIR="${PWD}/tmp"
if [ ! -d ${WORK_DIR} ];then
	mkdir -p ${WORK_DIR}
fi

# 源镜像文件
##########################################################################
source make.env
# 盒子型号识别参数 
SOC=s905x3
BOARD=multi

SUBVER=$1

MODULES_TGZ=${KERNEL_PKG_HOME}/modules-${KERNEL_VERSION}.tar.gz
BOOT_TGZ=${KERNEL_PKG_HOME}/boot-${KERNEL_VERSION}.tar.gz
DTBS_TGZ=${KERNEL_PKG_HOME}/dtb-amlogic-${KERNEL_VERSION}.tar.gz
if [ ! -f ${MODULES_TGZ} ];then
	echo "${MODULES_TGZ} not exists!"
	exit 1
fi
if [ ! -f ${BOOT_TGZ} ];then
	echo "${BOOT_TGZ} not exists!"
	exit 1
fi
if [ ! -f ${DTBS_TGZ} ];then
	echo "${DTBS_TGZ} not exists!"
	exit 1
fi
###########################################################################

# Openwrt root 源文件
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

# 目标镜像文件
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"

# 判断内核版本是否 >= 5.10
K_VER=$(echo "$KERNEL_VERSION" | cut -d '.' -f1)
K_MAJ=$(echo "$KERNEL_VERSION" | cut -d '.' -f2)

if [ $K_VER -eq 5 ];then
	if [ $K_MAJ -ge 10 ];then
		K510=1
	else
		K510=0
	fi
elif [ $K_VER -gt 5 ];then
	K510=1
else
	K510=0
fi

# 补丁和脚本
###########################################################################
REGULATORY_DB="${PWD}/files/regulatory.db.tar.gz"
KMOD="${PWD}/files/kmod"
KMOD_BLACKLIST="${PWD}/files/kmod_blacklist"
MAC_SCRIPT1="${PWD}/files/fix_wifi_macaddr.sh"
MAC_SCRIPT2="${PWD}/files/find_macaddr.pl"
MAC_SCRIPT3="${PWD}/files/inc_macaddr.pl"
CPUSTAT_SCRIPT="${PWD}/files/cpustat"
CPUSTAT_SCRIPT_PY="${PWD}/files/cpustat.py"
CPUSTAT_PATCH="${PWD}/files/luci-admin-status-index-html.patch"
CPUSTAT_PATCH_02="${PWD}/files/luci-admin-status-index-html-02.patch"
GETCPU_SCRIPT="${PWD}/files/getcpu"
TTYD="${PWD}/files/ttyd"
FLIPPY="${PWD}/files/flippy"
BANNER="${PWD}/files/banner"

# 20200314 add
FMW_HOME="${PWD}/files/firmware"
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

# 20200709 add
COREMARK="${PWD}/files/coremark.sh"

# 20200930 add
INST_SCRIPT="${PWD}/files/s905x3/install-to-emmc.sh"
UPDATE_SCRIPT="${PWD}/files/s905x3/update-to-emmc.sh"
SND_MOD="${PWD}/files/s905x3/snd-meson-g12"
BTLD_BIN="${PWD}/files/s905x3/hk1box-bootloader.img"
DAEMON_JSON="${PWD}/files/s905x3/daemon.json"

# 20201006 add
FORCE_REBOOT="${PWD}/files/s905x3/reboot"
# 20201017 add
BAL_ETH_IRQ="${PWD}/files/balethirq.pl"
# 20201026 add
FIX_CPU_FREQ="${PWD}/files/fixcpufreq.pl"
SYSFIXTIME_PATCH="${PWD}/files/sysfixtime.patch"

# 20201128 add
SSL_CNF_PATCH="${PWD}/files/openssl_engine.patch"

# 20201212 add
BAL_CONFIG="${PWD}/files/s905x3/balance_irq"
CPUFREQ_INIT="${PWD}/files/s905x3/cpufreq"

# 20210302 modify
FIP_HOME="${PWD}/files/meson_btld/with_fip/s905x3"
UBOOT_WITH_FIP="${FIP_HOME}/x96maxplus-u-boot.bin.sd.bin"
UBOOT_WITHOUT_FIP_HOME="${PWD}/files/meson_btld/without_fip"
UBOOT_WITHOUT_FIP="u-boot-ugoos-x3.bin"

# 20210208 add
WIRELESS_CONFIG="${PWD}/files/s905x3/wireless"

# 20210307 add
SS_LIB="${PWD}/files/ss-glibc/lib-glibc.tar.xz"
SS_BIN="${PWD}/files/s905x3/ss-bin-glibc.tar.xz"
JQ="${PWD}/files/jq"

# 20210330 add
DOCKERD_PATCH="${PWD}/files/dockerd.patch"

# 20200416 add
FIRMWARE_TXZ="${PWD}/files/firmware_armbian.tar.xz"
BOOTFILES_HOME="${PWD}/files/bootfiles/amlogic"
GET_RANDOM_MAC="${PWD}/files/get_random_mac.sh"

# 20210618 add
DOCKER_README="${PWD}/files/DockerReadme.pdf"
###########################################################################

# 检查环境
if [ $(id -u) -ne 0 ];then
	echo "这个脚本需要用root用户来执行，你好象不是root吧？"
	exit 1
fi

if [ ! -f "$OPWRT_ROOTFS_GZ" ];then
	echo "Openwrt镜像: ${OPWRT_ROOTFS_GZ} 不存在, 请检查!"
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

if parted --version >/dev/null 2>&1;then
	echo "check parted ok"
else
	echo "parted 程序不存在，请安装 parted"
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
losetup -D

# 创建空白镜像文件
echo "创建空白的目标镜像文件 ..."
SKIP_MB=4
BOOT_MB=256
ROOTFS_MB=640
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
if [ $? -ne 0 ];then
    echo "创建 boot 分区失败!"
    losetup -D
    exit 1
fi
BEGIN=$((END + 1))
END=$((ROOTFS_MB * 1024 * 1024 + BEGIN -1))
parted -s $TGT_DEV mkpart primary btrfs ${BEGIN}b 100% 2>/dev/null
if [ $? -ne 0 ];then
    echo "创建 rootfs 分区失败!"
    losetup -D
    exit 1
fi
parted -s $TGT_DEV print 2>/dev/null

# 格式化文件系统
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

echo "创建 /etc 子卷 ..."
btrfs subvolume create $TGT_ROOT/etc

# extract root
echo "openwrt 根文件系统解包 ... "
(
  cd $TGT_ROOT && \
  tar --exclude="./lib/firmware/*" --exclude="./lib/modules/*" -xzf $OPWRT_ROOTFS_GZ && \
  rm -rf ./lib/firmware/* ./lib/modules/* && \
  mkdir -p .reserved boot rom proc sys run
)

echo "Armbian firmware 解包 ... "
( 
  cd ${TGT_ROOT} && \
  tar xJf $FIRMWARE_TXZ
)
  
echo "内核模块解包 ... "
( 
  cd ${TGT_ROOT} && \
  mkdir -p lib/modules && \
  cd lib/modules && \
  tar xzf ${MODULES_TGZ}
)

echo "boot 文件解包 ... "
( 
  cd ${TGT_BOOT} && \
  cp -v "${BOOTFILES_HOME}"/* . && \
  tar xzf "${BOOT_TGZ}" && \
  rm -f initrd.img-${KERNEL_VERSION} && \
  cp -v vmlinuz-${KERNEL_VERSION} zImage && \
  cp -v uInitrd-${KERNEL_VERSION} uInitrd && \
  cp -v ${UBOOT_WITHOUT_FIP_HOME}/* . && \
  mkdir -p dtb/amlogic && \
  cd dtb/amlogic && \
  tar xzf "${DTBS_TGZ}" && \
  sync
)

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

# 用于 X96 Max+ (S905X3 网卡工作于 100m)
FDT=/dtb/amlogic/meson-sm1-x96-max-plus-100m.dtb

# 用于 X96 Max+ (S905X3 网卡工作于 1000M)
#FDT=/dtb/amlogic/meson-sm1-x96-max-plus.dtb

# 用于 X96 Max+ (S905X3 网卡工作于 1000M) (超频至2208Mhz)
#FDT=/dtb/amlogic/meson-sm1-x96-max-plus-oc.dtb

# 用于 HK1 BoX (S905X3 网卡工作于 1000M)
#FDT=/dtb/amlogic/meson-sm1-hk1box-vontar-x3.dtb

# 用于 HK1 BoX (S905X3 网卡工作于 1000M) (超频至2184Mhz)
#FDT=/dtb/amlogic/meson-sm1-hk1box-vontar-x3-oc.dtb

# 用于 H96 Max X3 (S905X3 网卡工作于 1000M)
#FDT=/dtb/amlogic/meson-sm1-h96-max-x3.dtb

# 用于 H96 Max X3 (S905X3 网卡工作于 1000M) (超频至2208Mhz)
#FDT=/dtb/amlogic/meson-sm1-h96-max-x3-oc.dtb

# 用于 Ugoos X3 Cube/Pro/Pro (网卡工作于1000M)
#FDT=/dtb/amlogic/meson-sm1-ugoos-x3.dtb

# 用于 Ugoos X3 Cube/Pro/Pro (网卡工作于1000M) (超频至2208Mhz)
#FDT=/dtb/amlogic/meson-sm1-ugoos-x3-oc.dtb

# 用于 X96 air 千兆版
#FDT=/dtb/amlogic/meson-sm1-x96-air-1000.dtb

# 用于 X96 air 百兆版
#FDT=/dtb/amlogic/meson-sm1-x96-air-100.dtb

# 用于 A95XF3 air 千兆版
#FDT=/dtb/amlogic/meson-sm1-a95xf3-air-1000.dtb

# 用于 A95XF3 air 百兆版
#FDT=/dtb/amlogic/meson-sm1-a95xf3-air-100.dtb

APPEND=root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

# 替换dtb文件
[ "$REPLACE_DTB" == "y" ] && [ -f "$DTB_FILE" ] && cp "$DTB_FILE" ./dtb/amlogic/

echo "uEnv.txt --->"
cat uEnv.txt

# 5.10以后的内核，需要增加u-boot重载
if [ $K510 -eq 1 ];then
	cp -fv ${UBOOT_WITHOUT_FIP} u-boot.ext
	rm -f u-boot.sd u-boot.usb
else
	rm -f u-boot*.bin
fi

echo "修改根文件系统相关配置 ... "

# modify root
cd $TGT_ROOT
( [ -f "$SS_LIB" ] &&  cd lib && tar xvJf "$SS_LIB" )
if [ -f "$SS_BIN" ];then
    (
        cd usr/bin
        mkdir -p ss-bin-musl && mv -f ss-server ss-redir ss-local ss-tunnel ss-bin-musl/ 2>/dev/null
       	tar xvJf "$SS_BIN"
    )
fi
if [ -f "$JQ" ] && [ ! -f "./usr/bin/jq" ];then
	cp -v ${JQ} ./usr/bin
fi

if [ -f "$BTLD_BIN" ];then
       mkdir -p lib/u-boot
       cp -v "$BTLD_BIN" lib/u-boot/ 
fi

if [ -d "${FIP_HOME}" ];then
       mkdir -p lib/u-boot
       cp -v "${FIP_HOME}"/../*.sh lib/u-boot/
       cp -v "${FIP_HOME}"/*.sd.bin lib/u-boot/ 
fi

[ -f $INST_SCRIPT ] && cp $INST_SCRIPT root/
# [ -f $UPDATE_SCRIPT ] && cp $UPDATE_SCRIPT root/
[ -f $MAC_SCRIPT1 ] && cp $MAC_SCRIPT1 usr/bin/
[ -f $MAC_SCRIPT2 ] && cp $MAC_SCRIPT2 usr/bin/
[ -f $MAC_SCRIPT3 ] && cp $MAC_SCRIPT3 usr/bin/
[ -f $DAEMON_JSON ] && mkdir -p "etc/docker" && cp $DAEMON_JSON "etc/docker/daemon.json"
[ -f $FORCE_REBOOT ] && cp $FORCE_REBOOT usr/sbin/
[ -f $COREMARK ] && [ -f "etc/coremark.sh" ] && cp -f $COREMARK "etc/coremark.sh" && chmod 755 "etc/coremark.sh"
if [ -x usr/bin/perl ];then
	[ -f $CPUSTAT_SCRIPT ] && cp $CPUSTAT_SCRIPT usr/bin/cpustat && chmod 755 usr/bin/cpustat
	[ -f $GETCPU_SCRIPT ] && cp $GETCPU_SCRIPT bin/
else
	[ -f $CPUSTAT_SCRIPT_PY ] && cp $CPUSTAT_SCRIPT_PY usr/bin/cpustat && chmod 755 usr/bin/cpustat
fi
#[ -f $TTYD ] && cp $TTYD etc/init.d/
[ -f $FLIPPY ] && cp $FLIPPY usr/sbin/
if [ -f $BANNER ];then
    cp -f $BANNER etc/banner
    echo " Base on OpenWrt ${OPENWRT_VER} by lean & lienol" >> etc/banner
    echo " Kernel ${KERNEL_VERSION}" >> etc/banner
    TODAY=$(date +%Y-%m-%d)
    echo " Packaged by ${WHOAMI} on ${TODAY}" >> etc/banner
    echo " SOC: ${SOC}	BOARD: ${BOARD}" >> etc/banner
    echo >> etc/banner
fi

if [ -f $BAL_ETH_IRQ ];then
    cp -v $BAL_ETH_IRQ usr/sbin
    chmod 755 usr/sbin/balethirq.pl
    sed -e "/exit/i\/usr/sbin/balethirq.pl" -i etc/rc.local
    [ -f ${BAL_CONFIG} ] && cp -v ${BAL_CONFIG} etc/config/
fi
[ -f $CPUFREQ_INIT ] && cp -v $CPUFREQ_INIT etc/init.d/ && chmod 755 etc/init.d/cpufreq
[ -f $WIRELESS_CONFIG ] && cp -v $WIRELESS_CONFIG etc/config/

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
if [ -f etc/init.d/dockerd ] && [ -f $DOCKERD_PATCH ];then
    patch -p1 < $DOCKERD_PATCH
fi
if [ -f usr/bin/xray-plugin ] && [ -f usr/bin/v2ray-plugin ];then
   ( cd usr/bin && rm -f v2ray-plugin && ln -s xray-plugin v2ray-plugin )
fi

[ -d ${FMW_HOME} ] && cp -a ${FMW_HOME}/* lib/firmware/
[ -f ${SYSCTL_CUSTOM_CONF} ] && cp ${SYSCTL_CUSTOM_CONF} etc/sysctl.d/
[ -f ${GET_RANDOM_MAC} ] && cp ${GET_RANDOM_MAC} usr/bin/
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
    echo "/mnt/mmcblk2p4 *(rw,sync,no_root_squash,insecure,no_subtree_check)" > ./etc/exports
    cat > ./etc/config/nfs <<EOF
config share
	option clients '*'
	option enabled '1'
	option options 'rw,sync,no_root_squash,insecure,no_subtree_check'
	option path '/mnt/mmcblk2p4'
EOF
fi

# for openclash
if [ -d ./etc/openclash/core ];then
    (
        mkdir -p ./usr/share/openclash/core && \
	cd ./etc/openclash && \
	mv core ../../usr/share/openclash/ && \
	ln -s ../../usr/share/openclash/core .
    )
fi

chmod 755 ./etc/init.d/*

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
        option anon_mount '1'
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

[ -f ./etc/docker-init ] && rm -f ./etc/docker-init
[ -f ./sbin/firstboot ] && rm -f ./sbin/firstboot
[ -f ./sbin/jffs2reset ] && rm -f ./sbin/jffs2reset ./sbin/jffs2mark
[ -f ./www/DockerReadme.pdf ] && [ -f ${DOCKER_README} ] && cp -fv ${DOCKER_README} ./www/DockerReadme.pdf

mkdir -p ./etc/modprobe.d
cat > ./etc/modprobe.d/99-local.conf <<EOF
blacklist snd_soc_meson_aiu_i2s
alias brnf br_netfilter
alias pwm pwm_meson
alias wifi brcmfmac
EOF

# echo br_netfilter > ./etc/modules.d/br_netfilter
echo pwm_meson > ./etc/modules.d/pwm_meson
echo panfrost > ./etc/modules.d/panfrost
#echo meson_gxbb_wdt > ./etc/modules.d/watchdog

mkdir ./etc/modules.d.remove
mod_blacklist=$(cat ${KMOD_BLACKLIST})
for mod in $mod_blacklist ;do
	mv -f ./etc/modules.d/${mod} ./etc/modules.d.remove/ 2>/dev/null
done

if [ $K510 -eq 1 ];then
    # 高版本内核下，如果ENABLE_WIFI_K510 = 0 则禁用wifi
    if [ $ENABLE_WIFI_K510 -eq 0 ];then
        mv -f ./etc/modules.d/brcm*  ./etc/modules.d.remove/ 2>/dev/null
    fi
else
    # 低版本内核下，如果ENABLE_WIFI_K504 = 0 则禁用wifi
    if [ $ENABLE_WIFI_K504 -eq 0 ];then
        mv -f ./etc/modules.d/brcm*  ./etc/modules.d.remove/ 2>/dev/null
    fi
fi

# 默认禁用sfe
[ -f ./etc/config/sfe ] && sed -e 's/option enabled '1'/option enabled '0'/' -i ./etc/config/sfe

[ -f ./etc/modules.d/usb-net-asix-ax88179 ] || echo "ax88179_178a" > ./etc/modules.d/usb-net-asix-ax88179
# +版内核，优先启用v2驱动, +o内核则启用v1驱动
if echo $KERNEL_VERSION | grep -E '*\+$' ;then
	echo "r8152" > ./etc/modules.d/usb-net-rtl8152
else
	echo "r8152" > ./etc/modules.d/usb-net-rtl8152
fi
[ -f ./etc/config/shairport-sync ] && [ -f ${SND_MOD} ] && cp ${SND_MOD} ./etc/modules.d/
echo "r8188eu" > ./etc/modules.d/rtl8188eu

rm -f ./etc/rc.d/S*dockerd

# 写入版本信息
cat > ./etc/flippy-openwrt-release <<EOF
SOC=${SOC}
BOARD=${BOARD}
KERNEL_VERSION=${KERNEL_VERSION}
K510=${K510}
SFE_FLAG=${SFE_FLAG}
FLOWOFFLOAD_FLAG=${FLOWOFFLOAD_FLAG}
EOF

if [ $K510 -eq 1 ];then
    cat >> ./etc/flippy-openwrt-release <<EOF
UBOOT_OVERLOAD=${UBOOT_WITHOUT_FIP}
EOF
fi

cd $TGT_ROOT/lib/modules/${KERNEL_VERSION}/
rm -f build source
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
if [ -f mount.ntfs3 ];then
    ln -sf mount.ntfs3 mount.ntfs
elif [ -f ../usr/bin/ntfs-3g ];then
    ln -sf /usr/bin/ntfs-3g mount.ntfs
fi

cd $TGT_ROOT/lib/firmware
mv *.hcd brcm/ 2>/dev/null
if [ -f "$REGULATORY_DB" ];then
	tar xzf "$REGULATORY_DB"
fi

cd brcm
source ${GET_RANDOM_MAC}

# gtking/gtking pro 采用 bcm4356 wifi/bluetooth 模块
get_random_mac
sed -e "s/macaddr=00:90:4c:1a:10:01/macaddr=${MACADDR}/" "brcmfmac4356-sdio.txt" > "brcmfmac4356-sdio.azw,gtking.txt"

# Phicomm N1 采用 bcm43455 wifi/bluetooth 模块
get_random_mac
sed -e "s/macaddr=b8:27:eb:74:f2:6c/macaddr=${MACADDR}/" "brcmfmac43455-sdio.txt" > "brcmfmac43455-sdio.phicomm,n1.txt"

# HK1 Box 和 H96 Max X3 采用 bcm54339 wifi/bluetooth 模块
get_random_mac
sed -e "s/macaddr=00:90:4c:c5:12:38/macaddr=${MACADDR}/" "brcmfmac4339-sdio.ZP.txt" > "brcmfmac4339-sdio.amlogic,sm1.txt"
get_random_mac
sed -e "s/macaddr=b8:27:eb:74:f2:6c/macaddr=${MACADDR}/" "brcmfmac43455-sdio.txt" > "brcmfmac43455-sdio.amlogic,sm1.txt"

rm -f ${TGT_ROOT}/etc/bench.log
cat >> ${TGT_ROOT}/etc/crontabs/root << EOF
37 5 * * * /etc/coremark.sh
EOF

[ -f $CPUSTAT_PATCH ] && cd $TGT_ROOT && patch -p1 < ${CPUSTAT_PATCH}
[ -x "${TGT_ROOT}/usr/bin/perl" ] && [ -f "${CPUSTAT_PATCH_02}" ] && cd ${TGT_ROOT} && patch -p1 < ${CPUSTAT_PATCH_02}

# 创建 /etc 初始快照
echo "创建初始快照: /etc -> /.snapshots/etc-000"
cd $TGT_ROOT && \
mkdir -p .snapshots && \
btrfs subvolume snapshot -r etc .snapshots/etc-000

# 2021.04.01添加
# 强制锁定fstab,防止用户擅自修改挂载点
# 开启了快照功能之后，不再需要锁定fstab
#chattr +ia ./etc/config/fstab

# clean temp_dir
cd $TEMP_DIR
umount -f $TGT_BOOT $TGT_ROOT 

# 写入完整的 u-boot 到 镜像文件
if [ -f ${UBOOT_WITH_FIP} ];then
    dd if=${UBOOT_WITH_FIP}  of=${TGT_DEV} conv=fsync,notrunc bs=512 skip=1 seek=1
    dd if=${UBOOT_WITH_FIP}  of=${TGT_DEV} conv=fsync,notrunc bs=1 count=444
fi

( losetup -D && cd $WORK_DIR && rm -rf $TEMP_DIR && losetup -D)
sync
echo
echo "镜像打包已完成，再见!"
