#!/bin/bash

echo "========================= begin $0 ================="
source make.env
source qemu-aarch64.env
source public_funcs
init_work_env

# Kernel image sources
###################################################################
MODULES_TGZ=${KERNEL_PKG_HOME}/modules-${KERNEL_VERSION}.tar.gz
check_file ${MODULES_TGZ}
BOOT_TGZ=${KERNEL_PKG_HOME}/boot-${KERNEL_VERSION}.tar.gz
check_file ${BOOT_TGZ}
###################################################################

# Openwrt
###################################################################
OPWRT_ROOTFS_GZ="${WORK_HOME}/${OP_ROOT_TGZ}"
check_file ${OPWRT_ROOTFS_GZ}
echo "Use $OPWRT_ROOTFS_GZ as openwrt rootfs!"
###################################################################

# Target raw Image
###################################################################
TGT_IMG="${WORK_DIR}/openwrt_${PLATFORM}_${SOC}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}_update.img"
# Target qcow2 Image
TGT_QCOW2_IMG="${OUTPUT_DIR}/openwrt_${PLATFORM}_${OPENWRT_VER}_k${KERNEL_VERSION}${SUBVER}.qcow2"
###################################################################

check_depends
SIZE=$((SKIP_MB + BOOT_MB + ROOTFS_MB + TAIL_MB))
create_image "$TGT_IMG" "$SIZE"
create_partition "$TGT_DEV" "gpt" "$SKIP_MB" "$BOOT_MB" "efi" "0" "-1" "btrfs"
make_filesystem "$TGT_DEV" "B" "fat16" "EFI" "R" "btrfs" "ROOTFS1"
mount_fs "${TGT_DEV}p1" "${TGT_BOOT}" "vfat"
mount_fs "${TGT_DEV}p2" "${TGT_ROOT}" "btrfs" "compress=zstd:${ZSTD_LEVEL}"
echo "创建 /etc 子卷 ..."
btrfs subvolume create $TGT_ROOT/etc
extract_rootfs_files
extract_qemu-aarch64_boot_files

echo "修改引导分区相关配置 ... "
cd "$TGT_BOOT/EFI/BOOT"
cat > grub.cfg <<EOF
echo "search fs_uuid ${ROOTFS_UUID} ..."
search.fs_uuid ${ROOTFS_UUID} root
echo "root=\$root"
echo "set prefix ... "
set prefix=(\$root)'/boot/grub2'
echo "prefix=\$prefix"
source \${prefix}/grub.cfg
EOF

cd "$TGT_ROOT/boot/grub2"
cat > grub.cfg <<EOF
insmod gzio
insmod part_gpt
insmod zstd
insmod btrfs
terminal_input console
terminal_output console
set default="0"
set timeout=3

menuentry "OpenWrt" {
	echo    'Loading linux kernel ...'
        linux /boot/vmlinuz root=UUID=${ROOTFS_UUID} rootfstype=btrfs rootflags=compress=zstd:${ZSTD_LEVEL} console=ttyAMA0,115200n8 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
	echo    'Loading initial ramdisk ...'
        initrd /boot/initrd.img
}
EOF

echo "grub.cfg -->"
echo "==============================================================================="
cat $TGT_BOOT/EFI/BOOT/grub.cfg
echo "-------------------------------------------------------------------------------"
cat $TGT_ROOT/boot/grub2/grub.cfg
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
adjust_nfs_config "vda4"
adjust_openssh_config
adjust_openclash_config
use_xrayplug_replace_v2rayplug
create_fstab_config
adjust_turboacc_config
adjust_ntfs_config
adjust_mosdns_config
patch_admin_status_index_html
adjust_kernel_env
write_release_info
write_banner
config_first_run
create_snapshot "etc-000"
clean_work_env
sync
echo "------------------------------------------------------------"
echo "转换 raw 格式为 qcow2 格式 ..."
qemu-img convert -f raw -O qcow2 ${TGT_IMG} ${TGT_QCOW2_IMG}
sync
echo "调整 qcow2 镜像大小: ${QCOW2_MB} ..."
qemu-img resize -f qcow2 ${TGT_QCOW2_IMG} ${QCOW2_MB}
sync
echo "------------------------------------------------------------"
mv ${TGT_IMG} ${OUTPUT_DIR}
sync
echo "镜像已生成, 存放在 ${OUTPUT_DIR} 下面"
echo "========================== end $0 ================================"
echo
