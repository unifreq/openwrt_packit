#!/bin/bash

echo "========================= begin $0 ================="
source make.env
source public_funcs
init_work_env

# 默认是否开启软件FLOWOFFLOAD
SW_FLOWOFFLOAD=0
# 默认是否开启硬件FLOWOFFLOAD
HW_FLOWOFFLOAD=0
# 默认是否开启SFE
SFE_FLOW=1

PLATFORM=rockchip
SOC=rk3568
BOARD=tx68
SUBVER=$1

# Kernel image sources
###################################################################
KERNEL_TAGS="rk35xx"
KERNEL_BRANCHES="bsp:rk35xx:>=:5.10 mainline:all:>=:6.1"
MODULES_TGZ=${KERNEL_PKG_HOME}/modules-${KERNEL_VERSION}.tar.gz
check_file ${MODULES_TGZ}
BOOT_TGZ=${KERNEL_PKG_HOME}/boot-${KERNEL_VERSION}.tar.gz
check_file ${BOOT_TGZ}
DTBS_TGZ=${KERNEL_PKG_HOME}/dtb-rockchip-${KERNEL_VERSION}.tar.gz
check_file ${DTBS_TGZ}
###################################################################

# Openwrt 
OPWRT_ROOTFS_GZ=$(get_openwrt_rootfs_archive ${PWD})
check_file ${OPWRT_ROOTFS_GZ}
echo "Use $OPWRT_ROOTFS_GZ as openwrt rootfs!"

# Target Image
TGT_IMG="${WORK_DIR}/openwrt_${SOC}_${BOARD}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.img"

# patches、scripts
####################################################################
CPUSTAT_SCRIPT="${PWD}/files/cpustat"
CPUSTAT_SCRIPT_PY="${PWD}/files/cpustat.py"
INDEX_PATCH_HOME="${PWD}/files/index.html.patches"
GETCPU_SCRIPT="${PWD}/files/getcpu"
KMOD="${PWD}/files/kmod"
KMOD_BLACKLIST="${PWD}/files/kmod_blacklist"

FIRSTRUN_SCRIPT="${PWD}/files/first_run.sh"

DAEMON_JSON="${PWD}/files/rk3568/daemon.json"

TTYD="${PWD}/files/ttyd"
FLIPPY="${PWD}/files/scripts_deprecated/flippy_cn"
BANNER="${PWD}/files/banner"

# 20200314 add
FMW_HOME="${PWD}/files/firmware"
SMB4_PATCH="${PWD}/files/smb4.11_enable_smb1.patch"
SYSCTL_CUSTOM_CONF="${PWD}/files/99-custom.conf"

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
BAL_CONFIG="${PWD}/files/rk3568/tx68/balance_irq"

# 20210307 add
SS_LIB="${PWD}/files/ss-glibc/lib-glibc.tar.xz"
SS_BIN="${PWD}/files/ss-glibc/armv8.2a_crypto/ss-bin-glibc.tar.xz"
JQ="${PWD}/files/jq"

# 20210330 add
DOCKERD_PATCH="${PWD}/files/dockerd.patch"

# 20200416 add
FIRMWARE_TXZ="${PWD}/files/firmware_armbian.tar.xz"
BOOTFILES_HOME="${PWD}/files/bootfiles/rockchip/rk3568/tx68"
GET_RANDOM_MAC="${PWD}/files/get_random_mac.sh"
BOOTLOADER_IMG="${PWD}/files/rk3568/tx68/bootloader.bin"

# 20210618 add
DOCKER_README="${PWD}/files/DockerReadme.pdf"

# 20210704 add
SYSINFO_SCRIPT="${PWD}/files/30-sysinfo.sh"
FORCE_REBOOT="${PWD}/files/rk3568/reboot"

# 20210923 add
OPENWRT_KERNEL="${PWD}/files/openwrt-kernel"
OPENWRT_BACKUP="${PWD}/files/openwrt-backup"
OPENWRT_UPDATE="${PWD}/files/openwrt-update-rockchip"
# 20211214 add
P7ZIP="${PWD}/files/7z"
# 20211217 add
DDBR="${PWD}/files/openwrt-ddbr"
# 20220225 add
SSH_CIPHERS="aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr,chacha20-poly1305@openssh.com"
SSHD_CIPHERS="aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
# 20220927 add
BOARD_HOME="${PWD}/files/rk3568/tx68/board.d"
# 20221001 add
MODULES_HOME="${PWD}/files/rk3568/modules.d"
# 20221123 add
BOARD_MODULES_HOME="${PWD}/files/rk3568/tx68/modules.d"
# 20221013 add
WIRELESS_CONFIG="${PWD}/files/rk3568/tx68/wireless"
# 20230622 add
NETWORK_SERVICE_PATCH="${PWD}/files/rk3568/tx68/network.patch"

# 20230921 add
#DC_VOLTAGE_PATCH="${PWD}/files/rk3568/h69k/dc_voltage.patch"
####################################################################

check_depends

SKIP_MB=16
BOOT_MB=256
ROOTFS_MB=960
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB + 1))
create_image "$TGT_IMG" "$SIZE"
create_partition "$TGT_DEV" "gpt" "$SKIP_MB" "$BOOT_MB" "ext4" "0" "-1" "btrfs"
make_filesystem "$TGT_DEV" "B" "ext4" "EMMC_BOOT" "R" "btrfs" "EMMC_ROOTFS1"
mount_fs "${TGT_DEV}p1" "${TGT_BOOT}" "ext4"
mount_fs "${TGT_DEV}p2" "${TGT_ROOT}" "btrfs" "compress=zstd:${ZSTD_LEVEL}"
echo "创建 /etc 子卷 ..."
btrfs subvolume create $TGT_ROOT/etc
extract_rootfs_files
extract_rockchip_boot_files

echo "修改引导分区相关配置 ... "
cd $TGT_BOOT
sed -e '/rootdev=/d' -i armbianEnv.txt
sed -e '/rootfstype=/d' -i armbianEnv.txt
sed -e '/rootflags=/d' -i armbianEnv.txt
cat >> armbianEnv.txt <<EOF
rootdev=UUID=${ROOTFS_UUID}
rootfstype=btrfs
rootflags=compress=zstd:${ZSTD_LEVEL}
EOF
echo "armbianEnv.txt -->"
echo "==============================================================================="
cat armbianEnv.txt
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
adjust_nfs_config "mmcblk0p4"
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
