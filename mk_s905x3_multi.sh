#!/bin/bash

echo "========================= begin $0 ==========================="
source make.env
source public_funcs
init_work_env

# 盒子型号识别参数 
PLATFORM=amlogic
SOC=s905x3
BOARD=multi

SUBVER=$1

# Kernel image sources
###################################################################
MODULES_TGZ=${KERNEL_PKG_HOME}/modules-${KERNEL_VERSION}.tar.gz
check_file ${MODULES_TGZ}
BOOT_TGZ=${KERNEL_PKG_HOME}/boot-${KERNEL_VERSION}.tar.gz
check_file ${BOOT_TGZ}
DTBS_TGZ=${KERNEL_PKG_HOME}/dtb-amlogic-${KERNEL_VERSION}.tar.gz
check_file ${DTBS_TGZ}
K510=$(get_k510_from_boot_tgz "${BOOT_TGZ}" "vmlinuz-${KERNEL_VERSION}")
export K510
###########################################################################

# Openwrt root 源文件
OP_ROOT_TGZ="openwrt-armvirt-64-default-rootfs.tar.gz"
OPWRT_ROOTFS_GZ="${PWD}/${OP_ROOT_TGZ}"
check_file ${OPWRT_ROOTFS_GZ}
echo "Use $OPWRT_ROOTFS_GZ as openwrt rootfs!"

# 目标镜像文件
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"

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
FLIPPY="${PWD}/files/scripts_deprecated/flippy_cn"
BANNER="${PWD}/files/banner"

# 20200314 add
FMW_HOME="${PWD}/files/firmware"
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

# 20200709 add
COREMARK="${PWD}/files/coremark.sh"

# 20200930 add
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
SS_BIN="${PWD}/files/ss-glibc/armv8.2a_crypto/ss-bin-glibc.tar.xz"
JQ="${PWD}/files/jq"

# 20210330 add
DOCKERD_PATCH="${PWD}/files/dockerd.patch"

# 20200416 add
FIRMWARE_TXZ="${PWD}/files/firmware_armbian.tar.xz"
BOOTFILES_HOME="${PWD}/files/bootfiles/amlogic"
GET_RANDOM_MAC="${PWD}/files/get_random_mac.sh"

# 20210618 add
DOCKER_README="${PWD}/files/DockerReadme.pdf"

# 20210704 add
SYSINFO_SCRIPT="${PWD}/files/30-sysinfo.sh"

# 20210923 add
OPENWRT_INSTALL="${PWD}/files/openwrt-install-amlogic"
OPENWRT_UPDATE="${PWD}/files/openwrt-update-amlogic"
OPENWRT_KERNEL="${PWD}/files/openwrt-kernel"
OPENWRT_BACKUP="${PWD}/files/openwrt-backup"

# 20211019 add
FIRSTRUN_SCRIPT="${PWD}/files/first_run.sh"

# 20211024 add
MODEL_DB="${PWD}/files/amlogic_model_database.txt"
# 20211214 add
P7ZIP="${PWD}/files/7z"
# 20211217 add
DDBR="${PWD}/files/openwrt-ddbr"
# 20220225 add
SSH_CIPHERS="aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr,chacha20-poly1305@openssh.com"
SSHD_CIPHERS="aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
###########################################################################

check_depends

SKIP_MB=4
BOOT_MB=160
ROOTFS_MB=736
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB))
create_image "$TGT_IMG" "$SIZE"
create_partition "$TGT_DEV" "msdos" "$SKIP_MB" "$BOOT_MB" "fat32" "0" "-1" "btrfs"
make_filesystem "$TGT_DEV" "B" "fat32" "BOOT" "R" "btrfs" "ROOTFS"
mount_fs "${TGT_DEV}p1" "${TGT_BOOT}" "vfat"
mount_fs "${TGT_DEV}p2" "${TGT_ROOT}" "btrfs" "compress=zstd:${ZSTD_LEVEL}"
echo "创建 /etc 子卷 ..."
btrfs subvolume create $TGT_ROOT/etc
extract_rootfs_files
extract_amlogic_boot_files

echo "修改引导分区相关配置 ... "
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

# 用于 X96 Max+ with IP1001M (S905X3 网卡工作于 1000M) (超频至2208Mhz)
#FDT=/dtb/amlogic/meson-sm1-x96-max-plus-ip1001m.dtb

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

# 用于 Tanix TX3 百兆版
#FDT=/dtb/amlogic/meson-sm1-tx3-bz.dtb

# 用于 Tanix TX3 百兆版 (超频至2208Mhz)
#FDT=/dtb/amlogic/meson-sm1-tx3-bz-oc.dtb

# 用于 Tanix TX3 千兆版
#FDT=/dtb/amlogic/meson-sm1-tx3-qz.dtb

# 用于 Tanix TX3 千兆版 (超频至2208Mhz)
#FDT=/dtb/amlogic/meson-sm1-tx3-qz-oc.dtb

APPEND=root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd:${ZSTD_LEVEL} console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF

echo "uEnv.txt -->"
echo "==============================================================================="
cat uEnv.txt
echo "==============================================================================="
echo

echo "修改根文件系统相关配置 ... "
cd $TGT_ROOT
copy_supplement_files 
extract_glibc_programs
adjust_docker_config
adjust_openssl_config
adjust_qbittorrent_config
adjust_getty_config
adjust_samba_config
adjust_nfs_config "mmcblk2p4"
adjust_openssh_config
adjust_openclash_config
use_xrayplug_replace_v2rayplug
create_fstab_config
adjust_turboacc_config
adjust_ntfs_config
adjust_mosdns_config
patch_admin_status_index_html
adjust_kernel_env
copy_uboot_to_fs
write_release_info
write_banner
config_first_run
create_snapshot "etc-000"
write_uboot_to_disk
clean_work_env
mv ${TGT_IMG} ${OUTPUT_DIR} && sync
echo "镜像已生成! 存放在 ${OUTPUT_DIR} 下面!"
echo "========================== end $0 ================================"
echo
