#!/bin/bash

WORK_DIR="${PWD}/tmp"
if [ ! -d ${WORK_DIR} ];then
	mkdir -p ${WORK_DIR}
fi

# Image sources
######################################################################
source make.env
SOC="rk3328"
BOARD="l1pro"
SUBVER=$1
LNX_IMG="/opt/imgs/Armbian_20.10_L1-Pro_buster_${KERNEL_VERSION}.img"

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
# BOOT_TGZ="${PWD}/boot-${KERNEL_VERSION}.tar.gz"
# MODULES_TGZ="/opt/imgs/modules-${KERNEL_VERSION}.tar.gz"
######################################################################

# target image
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"

# patches, scripts
#####################################################################
REGULATORY_DB="${PWD}/files/regulatory.db.tar.gz"
CPUSTAT_SCRIPT="${PWD}/files/cpustat"
CPUSTAT_SCRIPT_PY="${PWD}/files/cpustat.py"
CPUSTAT_PATCH="${PWD}/files/luci-admin-status-index-html.patch"
RC_BOOT_PATCH="${PWD}/files/boot-rk.patch"
GETCPU_SCRIPT="${PWD}/files/getcpu"
UPDATE_SCRIPT="${PWD}/files/update-l1pro-openwrt.sh"
KMOD="${PWD}/files/kmod"
KMOD_BLACKLIST="${PWD}/files/kmod_blacklist"

FIRSTRUN_SCRIPT="${PWD}/files/mk_newpart.sh"
BOOT_CMD="${PWD}/files/boot.cmd"
BOOT_SCR="${PWD}/files/boot.scr"

PWM_FAN="${PWD}/files/pwm-fan.pl"
DAEMON_JSON="${PWD}/files/daemon.json.p4"

TTYD="${PWD}/files/ttyd"
FLIPPY="${PWD}/files/flippy"
BANNER="${PWD}/files/banner"

# 20200314 add
FMW_HOME="${PWD}/files/firmware"
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

# 20200404 add
SND_MOD="${PWD}/files/snd-rk3328"

# 20200709 add
COREMARK="${PWD}/files/coremark.sh"

# 20201024 add
BAL_ETH_IRQ="${PWD}/files/balethirq.pl"
# 20201026 add
FIX_CPU_FREQ="${PWD}/files/fixcpufreq.pl"
SYSFIXTIME_PATCH="${PWD}/files/sysfixtime.patch"

# 20201128 add
SSL_CNF_PATCH="${PWD}/files/openssl_engine.patch"

# 20201212 add
BAL_CONFIG="${PWD}/files/rk3328/balance_irq"

# 20210307 add
SS_LIB="${PWD}/files/ss-glibc/lib-glibc.tar.xz"
SS_BIN="${PWD}/files/ss-glibc/ss-bin-glibc.tar.xz"
JQ="${PWD}/files/jq"

# 20210330 add
DOCKERD_PATCH="${PWD}/files/dockerd.patch"
#####################################################################

SKIP_MB=16
BOOT_MB=160
ROOTFS_MB=720

# work dir
cd $WORK_DIR
TEMP_DIR=$(mktemp -p $WORK_DIR)
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR
echo $TEMP_DIR

# temp dir
cd $TEMP_DIR
LINUX_ROOT=armbian_root
mkdir $LINUX_ROOT

# mount & tar xf
losetup -D
losetup -f -P $LNX_IMG
SRC_DEV=$(losetup | grep "$LNX_IMG" | head -n 1 | gawk '{print $1}')
echo "source dev is $SRC_DEV"
BOOTLOADER_IMG=${WORK_DIR}/btld-rk3328.bin
dd if=${SRC_DEV} of=${BOOTLOADER_IMG} bs=1M count=${SKIP_MB}
sync
mount -o ro ${SRC_DEV}p2 $LINUX_ROOT
mount -o ro ${SRC_DEV}p1 $LINUX_ROOT/boot

# mk tgt_img
#SIZE1=$(du -k $OPWRT_ROOT | tail -n 1 | gawk '{print $1}')
#SIZE2=$(du -k $LINUX_ROOT/lib/modules | tail -n 1 | gawk '{print $1}')
#SIZE3=$(du -k $LINUX_ROOT/lib/firmware | tail -n 1 |gawk '{print $1}')
#SIZE=$((SIZE1 + SIZE2 + SIZE3))
#SIZE=$((SIZE / 1024 + BOOT_MB + SKIP_MB + 64))
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB))

echo "DISK SIZE = $SIZE MB"
dd if=/dev/zero of=$TGT_IMG bs=1M count=$SIZE
losetup -f -P $TGT_IMG
TGT_DEV=$(losetup | grep "$TGT_IMG" | gawk '{print $1}')
echo "Target dev is $TGT_DEV"

# make partition
parted -s $TGT_DEV mklabel msdos 2>/dev/null
START=$((SKIP_MB * 1024 * 1024))
END=$((BOOT_MB * 1024 * 1024 + START -1))
parted -s $TGT_DEV mkpart primary ext4 ${START}b ${END}b 2>/dev/null
START=$((END + 1))
END=$((ROOTFS_MB * 1024 * 1024 + START -1))
parted -s $TGT_DEV mkpart primary btrfs ${START}b 100% 2>/dev/null
parted -s $TGT_DEV print 2>/dev/null

# mk boot filesystem (ext4)
BOOT_UUID=$(uuidgen)
mkfs.ext4 -U ${BOOT_UUID} -L EMMC_BOOT ${TGT_DEV}p1
echo "BOOT UUID IS $BOOT_UUID"
# mk root filesystem (btrfs)
ROOTFS_UUID=$(uuidgen)
mkfs.btrfs -U ${ROOTFS_UUID} -L EMMC_ROOTFS1 -m single ${TGT_DEV}p2
echo "ROOTFS UUID IS $ROOTFS_UUID"

echo "parted ok"

# write bootloader
dd if=${BOOTLOADER_IMG} of=${TGT_DEV} bs=1 count=442 conv=fsync
dd if=${BOOTLOADER_IMG} of=${TGT_DEV} bs=512 skip=1 seek=1 conv=fsync
sync

TGT_BOOT=${TEMP_DIR}/tgt_boot
TGT_ROOT=${TEMP_DIR}/tgt_root
mkdir $TGT_BOOT $TGT_ROOT
mount -t ext4 ${TGT_DEV}p1 $TGT_BOOT
mount -t btrfs -o compress=zstd ${TGT_DEV}p2 $TGT_ROOT

# extract root
echo "extract openwrt rootfs ... "
(
  cd $TGT_ROOT && \
	  tar xzf $OPWRT_ROOTFS_GZ && \
	  rm -rf ./lib/firmware/* ./lib/modules/* && \
	  mkdir -p .reserved boot rom proc sys run
)

echo "extract armbian rootfs ... "
cd $TEMP_DIR/$LINUX_ROOT && \
	tar cf - ./etc/armbian* ./etc/default/armbian* ./etc/default/cpufreq* ./lib/init ./lib/lsb ./lib/firmware ./usr/lib/armbian | (cd ${TGT_ROOT}; tar xf -)

echo "extract kernel modules ... "
cd $TEMP_DIR/$LINUX_ROOT
#if [ -f "${MODULES_TGZ}" ];then
#	(cd ${TGT_ROOT}/lib/modules; tar xvzf "${MODULES_TGZ}")
#else
	tar cf - ./lib/modules | ( cd ${TGT_ROOT}; tar xf - )
#fi

echo "extract boot ... "
# extract boot
cd $TEMP_DIR/$LINUX_ROOT/boot
#if [ -f "${BOOT_TGZ}" ];then
#	( cd $TGT_BOOT; tar xvzf "${BOOT_TGZ}" )
#else
#tar cf - . | (cd $TGT_BOOT; tar xf - ;  find . -name 'rk3328-l1pro*.dtb' -exec cp -v {} . \;)
tar cf - . | (cd $TGT_BOOT; tar xf -)
#; find ./dtb -name 'rk3328-l1pro*.dtb' -exec cp -v {} . \; ;[ -f rk3328-l1pro.dtb ] || ln -s rk3328-l1pro-1296mhz.dtb rk3328-l1pro.dtb; [ -f rk3328-l1pro-oc.dtb ] || ln -s rk3328-l1pro-1512mhz.dtb rk3328-l1pro-oc.dtb)
#fi

echo "modify boot ... "
# modify boot
cd $TGT_BOOT
[ -f $BOOT_CMD ] && cp $BOOT_CMD boot.cmd
[ -f $BOOT_SCR ] && cp $BOOT_SCR boot.scr
ln -sf ./dtb-${KERNEL_VERSION}/rockchip/rk3328-l1pro*.dtb .
cat > armbianEnv.txt <<EOF
verbosity=7
overlay_prefix=rockchip
rootdev=/dev/mmcblk0p2
rootfstype=btrfs
rootflags=compress=zstd
extraargs=usbcore.autosuspend=-1
extraboardargs=
fdtfile=/dtb/rockchip/rk3328-l1pro-1296mhz.dtb
EOF

echo "modify root ... "
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

if [ -f "$PWM_FAN" ];then
	cp $PWM_FAN ./usr/bin
	echo "pwm_fan" > ./etc/modules.d/pwm_fan
	cat > "./etc/rc.local" <<EOF
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.
/usr/bin/pwm-fan.pl &
exit 0
EOF
fi

if [ -f "$FIRSTRUN_SCRIPT" ];then
	chmod 755 "$FIRSTRUN_SCRIPT"
 	cp "$FIRSTRUN_SCRIPT" ./usr/bin/ 
	mv ./etc/rc.local ./etc/rc.local.orig
	cat > ./etc/part_size <<EOF
${SKIP_MB}	${BOOT_MB}	${ROOTFS_MB}
EOF

	cat > "./etc/rc.local" <<EOF
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.
/usr/bin/pwm-fan.pl &
/usr/bin/mk_newpart.sh 1>/dev/null 2>&1
exit 0
EOF
fi

[ -f $DAEMON_JSON ] && mkdir -p "etc/docker" && cp $DAEMON_JSON "etc/docker/daemon.json"
[ -f $COREMARK ] && [ -f "etc/coremark.sh" ] && cp -f $COREMARK "etc/coremark.sh" && chmod 755 "etc/coremark.sh"
if [ -x usr/bin/perl ];then
	[ -f $CPUSTAT_SCRIPT ] && cp $CPUSTAT_SCRIPT usr/bin/
	[ -f $GETCPU_SCRIPT ] && cp $GETCPU_SCRIPT bin/
else
	[ -f $CPUSTAT_SCRIPT_PY ] && cp $CPUSTAT_SCRIPT_PY usr/bin/cpustat
fi
[ -f $UPDATE_SCRIPT ] && cp $UPDATE_SCRIPT usr/bin/
[ -f $TTYD ] && cp $TTYD etc/init.d/
[ -f $FLIPPY ] && cp $FLIPPY usr/sbin/
if [ -f $BANNER ];then
    cp -f $BANNER etc/banner
    echo " Base on OpenWrt ${OPENWRT_VER} by lean & lienol" >> etc/banner
    echo " Kernel ${KERNEL_VERSION}" >> etc/banner
    TODAY=$(date +%Y-%m-%d)
    echo " Packaged by ${WHOAMI} on ${TODAY}" >> etc/banner
    echo " SOC: ${SOC}  BOARD: ${BOARD}" >> etc/banner
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
if [ -f etc/init.d/dockerd ] && [ -f $DOCKERD_PATCH ];then
    patch -p1 < $DOCKERD_PATCH
fi

[ -d ${FMW_HOME} ] && cp -a ${FMW_HOME}/* lib/firmware/
[ -d ${FMW_HOME} ] && cp -a ${FMW_HOME}/* lib/firmware/
[ -f ${SYSCTL_CUSTOM_CONF} ] && cp ${SYSCTL_CUSTOM_CONF} etc/sysctl.d/
[ -d overlay ] || mkdir -p overlay
[ -d rom ] || mkdir -p rom
[ -d sys ] || mkdir -p sys
[ -d proc ] || mkdir -p proc
[ -d run ] || mkdir -p run

mkdir ./etc/modules.d.remove
mv -f ./etc/modules.d/brcm* ./etc/modules.d.remove/ 2>/dev/null
mod_blacklist=$(cat ${KMOD_BLACKLIST})
for mod in $mod_blacklist ;do
	mv -f ./etc/modules.d/${mod} ./etc/modules.d.remove/ 2>/dev/null
done
[ -f ./etc/modules.d/usb-net-asix-ax88179 ] || echo "ax88179_178a" > ./etc/modules.d/usb-net-asix-ax88179
# +版内核，优先启用v2驱动, +o内核则启用v1驱动
if echo $KERNEL_VERSION | grep -E '*\+$' ;then
	echo "r8152" > ./etc/modules.d/usb-net-rtl8152
else
	echo "r8152" > ./etc/modules.d/usb-net-rtl8152
fi
[ -f ./etc/config/shairport-sync ] && [ -f ${SND_MOD} ] && cp ${SND_MOD} ./etc/modules.d/
echo "r8188eu" > ./etc/modules.d/rtl8188eu

sed -e 's/ttyAMA0/tty1/' -i ./etc/inittab
sed -e 's/ttyS0/ttyS2/' -i ./etc/inittab
sed -e 's/\/opt/\/etc/' -i ./etc/config/qbittorrent
patch -p0 < "${RC_BOOT_PATCH}"
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
    echo "/mnt/mmcblk0p4 *(rw,sync,no_root_squash,insecure,no_subtree_check)" > ./etc/exports
    cat > ./etc/config/nfs <<EOF
config share
	option clients '*'
	option enabled '1'
	option options 'rw,sync,no_root_squash,insecure,no_subtree_check'
	option path '/mnt/mmcblk0p4'
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
UUID=${BOOT_UUID} /boot ext4 noatime,errors=remount-ro 0 2
tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF

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
        option fstype 'btrfs'
        option options 'compress=zstd'

config mount
        option target '/boot'
        option uuid '${BOOT_UUID}'
        option enabled '1'
        option enabled_fsck '0'
	option fstype 'ext4'

EOF

# 2021.04.01添加
# 强制锁定fstab,防止用户擅自修改挂载点
chattr +ia ./etc/config/fstab

rm -f ./etc/bench.log
cat >> ./etc/crontabs/root << EOF
17 3 * * * /etc/coremark.sh
EOF

mkdir -p ./etc/modprobe.d

#echo br_netfilter > ./etc/modules.d/br_netfilter

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
	tar xvzf "$REGULATORY_DB"
fi

[ -f $CPUSTAT_PATCH ] && \
cd $TGT_ROOT/usr/lib/lua/luci/view/admin_status && \
patch -p0 < ${CPUSTAT_PATCH} 


# make new rootfs tgz
#echo
#echo
# echo "package new root archive ..."
# cd $TGT_ROOT
# TGT_ROOT_TGZ="${WORK_DIR}/L1-Pro_Openwrt_${OPENWRT_VER}_k${KERNEL_VERSION}_rootfs.tar.gz"
# tar cvf - . | pigz -9 > $TGT_ROOT_TGZ

# clean temp_dir
cd $TEMP_DIR
umount -f $LINUX_ROOT/boot $LINUX_ROOT $TGT_ROOT $TGT_BOOT
( losetup -D && cd $WORK_DIR && rm -rf $TEMP_DIR && losetup -D)
sync
echo "done!"
