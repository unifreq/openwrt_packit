#!/bin/bash

# check cmd param
if [ "$1" == "" ];then
    echo "用法: $0 xxx.img"
    exit 1
fi

# 检查镜像文件是否存在
IMG_NAME=$1
if [ ! -f "$IMG_NAME" ];then
    echo "$IMG_NAME 不存在!"
    exit 1
fi

# 查找当前的 /boot 分区信息
DEPENDS="lsblk uuidgen grep awk mkfs.fat mkfs.btrfs perl"
for dep in ${DEPENDS};do
    which $dep
    if [ $? -ne 0 ];then
        echo "依赖的命令: $dep 不存在！"
	exit 1
    fi
done

BOOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | awk '$3~/^part$/ && $5 ~ /^\/boot$/ {print $0}')
if [ "${BOOT_PART_MSG}" == "" ];then
    echo "Boot 分区不存在，或是没有正确挂载, 因此无法继续升级!"
    exit 1
fi

# 获得当前使用的 dtb 文件名
cp /boot/uEnv.txt /tmp/
source /boot/uEnv.txt 2>/dev/null
CUR_FDTFILE=${FDT}
if [ "${CUR_FDTFILE}" == "" ];then
    echo "警告: 未查到当前使用的 dtb 文件名，可能影响后面的升级(也可能不影响)"
fi

# 获得当前固件的参数
CUR_SOC=""
CUR_BOARD=""
if [ -f /etc/flippy-openwrt-release ];then
    source /etc/flippy-openwrt-release
    CUR_SOC=$SOC
    CUR_BOARD=$BOARD
fi

CUR_KV=$(uname -r)
# 判断内核版本是否 >= 5.10
CK_VER=$(echo "$CUR_KV" | cut -d '.' -f1)
CK_MAJ=$(echo "$CUR_KV" | cut -d '.' -f2)

if [ $CK_VER -eq 5 ];then
    if [ $CK_MAJ -ge 10 ];then
        CUR_K510=1
    else
        CUR_K510=0
    fi
elif [ $CK_VER -gt 5 ];then
    CUR_K510=1
else
    CUR_K510=0
fi

# 备份标志
BR_FLAG=1
echo -ne "你想要备份旧版本的配置，并将其还原到升级后的系统中吗? y/n [y]\b\b"
read yn
case $yn in
     n*|N*) BR_FLAG=0;;
esac

BOOT_NAME=$(echo $BOOT_PART_MSG | awk '{print $1}')
BOOT_PATH=$(echo $BOOT_PART_MSG | awk '{print $2}')
BOOT_UUID=$(echo $BOOT_PART_MSG | awk '{print $4}')

# emmc设备具有  /dev/mmcblk?p?boot0、/dev/mmcblk?p?boot1等2个特殊设备, tf卡或u盘则不存在该设备
MMCBOOT0=${BOOT_PATH%%p*}boot0
if [ -b "${MMCBOOT0}" ];then
    CUR_BOOT_FROM_EMMC=1        # BOOT是EMMC 
    echo "当前的 boot 分区在 EMMC 里"
    cp /boot/u-boot.ext  /tmp/ 2>/dev/null
    cp /boot/u-boot.emmc /tmp/ 2>/dev/null
    BOOT_LABEL="EMMC_BOOT"
else
    CUR_BOOT_FROM_EMMC=0        # BOOT 不是 EMMC
    if echo "${BOOT_PATH}" | grep "mmcblk" > /dev/null;then
        echo "当前的 boot 分区在 TF卡 里"
    else
        echo "当前的 boot 分区在 U盘 里"
    fi
    cp /boot/u-boot.ext  /tmp/ 2>/dev/null
    cp /boot/u-boot.emmc /tmp/ 2>/dev/null
    BOOT_LABEL="BOOT"
fi

# find root partition 
ROOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | awk '$3~/^part$/ && $5 ~ /^\/$/ {print $0}')
ROOT_NAME=$(echo $ROOT_PART_MSG | awk '{print $1}')
ROOT_PATH=$(echo $ROOT_PART_MSG | awk '{print $2}')
ROOT_UUID=$(echo $ROOT_PART_MSG | awk '{print $4}')
case $ROOT_NAME in 
  mmcblk1p2) NEW_ROOT_NAME=mmcblk1p3
             NEW_ROOT_LABEL=EMMC_ROOTFS2
             ;;
  mmcblk1p3) NEW_ROOT_NAME=mmcblk1p2
             NEW_ROOT_LABEL=EMMC_ROOTFS1
             ;;
  mmcblk2p2) NEW_ROOT_NAME=mmcblk2p3
             NEW_ROOT_LABEL=EMMC_ROOTFS2
             ;;
  mmcblk2p3) NEW_ROOT_NAME=mmcblk2p2
             NEW_ROOT_LABEL=EMMC_ROOTFS1
             ;;
          *) echo "ROOTFS 分区位置不正确, 因此无法继续升级!"
             exit 1
             ;;
esac

# find new root partition
NEW_ROOT_PART_MSG=$(lsblk -l -o NAME,PATH,TYPE,UUID,MOUNTPOINT | grep "${NEW_ROOT_NAME}" | awk '$3 ~ /^part$/ && $5 !~ /^\/$/ && $5 !~ /^\/boot$/ {print $0}')
if [ "${NEW_ROOT_PART_MSG}" == "" ];then
    echo "新的 ROOTFS 分区不存在, 因此无法继续升级!"
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
        echo "loop 设备未找到!"
        exit 1
    fi
else
    echo "losetup $IMG_FILE 失败!"
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
        echo -n "卸载 $dev ... "
        umount -f $dev
        sleep 1
        mnt=$(lsblk -l -o NAME,PATH,MOUNTPOINT | grep "$dev" | awk '$3 !~ /^$/ {print $2}')
        if [ "$mnt" == "" ];then
            echo "成功"
            break
        else 
            echo "重试 ..."
        fi
    done
done

# mount src part
WORK_DIR=$PWD
P1=${WORK_DIR}/boot
P2=${WORK_DIR}/root
mkdir -p $P1 $P2
echo -n "挂载 ${LOOP_DEV}p1 -> ${P1} ... "
mount -t vfat -o ro ${LOOP_DEV}p1 ${P1}
if [ $? -ne 0 ];then
    echo "挂载失败!"
    losetup -D
    exit 1
else 
    echo "成功"
fi        

echo -n "挂载 ${LOOP_DEV}p2 -> ${P2} ... "
mount -t btrfs -o ro,compress=zstd ${LOOP_DEV}p2 ${P2}
if [ $? -ne 0 ];then
    echo "挂载失败!"
    umount -f ${P1}
    losetup -D
    exit 1
else
    echo "成功"
fi        

# 检查新旧版本
NEW_SOC=""
NEW_BOARD=""
if [ -f ${P2}/etc/flippy-openwrt-release ];then
    source ${P2}/etc/flippy-openwrt-release
    NEW_SOC=${SOC}
    NEW_BOARD=${BOARD}
fi

NEW_KV=$(ls ${P2}/lib/modules/)
# 判断内核版本是否 >= 5.10
NK_VER=$(echo "$NEW_KV" | cut -d '.' -f1)
NK_MAJ=$(echo "$NEW_KV" | cut -d '.' -f2)

if [ $NK_VER -eq 5 ];then
    if [ $NK_MAJ -ge 10 ];then
        NEW_K510=1
    else
        NEW_K510=0
    fi
elif [ $NK_VER -gt 5 ];then
    NEW_K510=1
else
    NEW_K510=0
fi

if [ "${CUR_SOC}" != "" ];then
    if [ "${CUR_SOC}" != "${NEW_SOC}" ];then
        echo "采用的镜像文件与当前环境的 SOC 不匹配, 请检查！"
        umount -f ${P1}
        umount -f ${P2}
        losetup -D
        exit 1
    else
        if [ "${CUR_BOARD}" != "" ];then
            if [ "${CUR_BOARD}" != "${NEW_BOARD}" ];then
                echo "采用的镜像文件与当前环境的 BOARD 不匹配, 请检查！"
                umount -f ${P1}
                umount -f ${P2}
                losetup -D
                exit 1
            fi
        fi
    fi
fi

# 判断要刷的版本
echo $NEW_KV | grep -E 'flippy-[0-9]{1,3}\+[o]{0,1}' > /dev/null
if [ $? -ne 0 ];then
    echo "目标固件的内核版本格式无法识别！"
    umount -f ${P1}
    umount -f ${P2}
    losetup -D
    exit 1
fi

NEW_FLIPPY_VER=${NEW_KV##*-}
NEW_FLIPPY_NUM=${NEW_FLIPPY_VER%+*}
if [ $NEW_FLIPPY_NUM -ge 54 ];then
    echo "本脚本不支持升级到 54+ 或 54+o 以上的版本，请换成 update-amlogic-openwrt.sh"
    umount -f ${P1}
    umount -f ${P2}
    losetup -D
    exit 1
fi

UP=0
DOWN=0
if [ $CUR_K510 -ne $NEW_K510 ];then
    if [ $CUR_K510 -lt $NEW_K510 ];then
        UP=1
        DOWN=0
    else
        UP=0
        DOWN=1
    fi
fi

BOOT_CHANGED=0
if [ $UP -eq 1 ];then   # 内核升级
    # 升级到 >= 5.10 内核，不能 从 emmc 启动， 需要做 boot 迁移
    if [ ${CUR_BOOT_FROM_EMMC} -eq 1 ];then
        # 需要找到新的boot分区
        while : ;do
	    # 查找当前存在的 fat32 分区(排除正在使用中 /boot 分区)
            NEW_BOOT_MSG=$(lsblk -l -o PATH,NAME,TYPE,FSTYPE,MOUNTPOINT | grep "vfat" | grep -v "loop" | grep -v "${BOOT_PATH}" | head -n 1)                
            if [ "${NEW_BOOT_MSG}" == "" ];then
                read -p "未发现 ${BOOT_PATH} 以外的 fat32 格式的分区, 请插入一个带有 fat32 分区的 u盘或 tf卡设备, 按回车键继续，或者按 q 退出. " pause
                case $pause in 
                    q|Q) echo "再见!"
                         umount -f $P1
                         umount -f $P2
                         losetup -D
                         exit 1
                         ;;
                esac
            else
                NEW_BOOT_PATH=$(echo $NEW_BOOT_MSG | awk '{print $1}')
                NEW_BOOT_NAME=$(echo $NEW_BOOT_MSG | awk '{print $2}')
                NEW_BOOT_MOUNTPOINT=$(echo $NEW_BOOT_MSG | awk '{print $5}')
                read -p "新的 boot 设备是 $NEW_BOOT_PATH , 你确认吗？ y/n " pause
                case $pause in 
                    n|N) echo "无法找到合适的boot设备， 再见!"
                         umount -f $P1
                         umount -f $P2
                         losetup -D
                         exit 1
                         ;;
                    y|Y) break  # 确认新设备
                         ;;
                esac
           fi
       done

       while :;do
           read -p "将要重新格式化 $NEW_BOOT_PATH 设备,里面的数据将会丢失， 确认吗? y/n " yn
           case $yn in 
               n|N) echo "再见!"
                    umount -f $P1
                    umount -f $P2
                    losetup -D
                    exit 1
                    ;;
               y|Y) BOOT_LABEL="BOOT"
		    if [ "${NEW_BOOT_MOUNTPOINT}" != "" ];then
                        echo "卸载 ${NEW_BOOT_MOUNTPOINT} ..."
                        umount -f ${NEW_BOOT_MOUNTPOINT}
                        if [ $? -ne 0 ];then
                            echo "无法卸载 ${NEW_BOOT_MOUNTPOINT}, 再见"
                            umount -f $P1
                            umount -f $P2
                            losetup -D
                            exit 1
                        fi
                    else
                        mkdir -p /mnt/${NEW_BOOT_NAME}
                    fi
                    echo "格式化 $NEW_BOOT_PATH ..."
                    mkfs.fat -F 32 -n "${BOOT_LABEL}" $NEW_BOOT_PATH

                    echo "挂载 $NEW_BOOT_PATH ->  /mnt/${NEW_BOOT_NAME} ..."
                    mount $NEW_BOOT_PATH  /mnt/${NEW_BOOT_NAME} 
                    if [ $? -ne 0 ];then
                        echo "挂载 $NEW_BOOT_PATH ->  /mnt/${NEW_BOOT_NAME} 失败!"
                        umount -f $P1
                        umount -f $P2
                        loseup -D
                        exit 1
                    fi

                    echo "复制 /boot ->  /mnt/${NEW_BOOT_NAME} ..."
                    cp -a  /boot/*  /mnt/${NEW_BOOT_NAME}/

                    echo "切换 boot ..."
                    umount -f /boot && \
                    umount -f /mnt/${NEW_BOOT_NAME} && \
                    mount ${NEW_BOOT_PATH}  /boot
                    if [ $? -ne 0 ];then
                        echo "切换失败!"
                        umount -f $P1
                        umount -f $P2
                        loseup -D
                        exit 1
                   else
                        echo "/boot 已切换到  ${NEW_BOOT_PATH} "
                        BOOT_CHANGED=1
                   fi
                   break 
                   ;;
           esac
       done
   fi
elif [ $DOWN -eq 1 ];then # 内核降级
   # 降级到 < 5.10 内核，可以从 emmc 启动，也可以从 tf卡、u盘启动，可选择是否迁移 boot
   if [ $CUR_BOOT_FROM_EMMC -eq 0 ];then
       while :;do # do level 1
           read -p "内核降级到 5.10 以下, 可以从 EMMC 启动，你需要切换 boot 到 EMMC 吗？ y/n " yn1
           case $yn1 in 
               n|N)  break;;
               y|Y)  NEW_BOOT_MSG=$(lsblk -l -o PATH,NAME,TYPE,FSTYPE,MOUNTPOINT | grep "vfat" | grep -v "loop" | grep -v "${BOOT_PATH}" | head -n 1)
                     if [ "${NEW_BOOT_MSG}" == "" ];then
                         echo "很抱歉，未发现 emmc 里可用的 fat32 分区, 再见！"
                         umount -f $P1
                         umount -f $P2
                         losetup -D
                         exit 1
                     fi
                     NEW_BOOT_PATH=$(echo $NEW_BOOT_MSG | awk '{print $1}')
                     NEW_BOOT_NAME=$(echo $NEW_BOOT_MSG | awk '{print $2}')
                     NEW_BOOT_MOUNTPOINT=$(echo $NEW_BOOT_MSG | awk '{print $5}')
                     read -p "新的 boot 设备是 $NEW_BOOT_PATH , 确认吗？ y/n " pause

                     NEW_BOOT_OK=0
                     case $pause in 
                         n|N) echo "无法找到合适的boot设备， 再见!"
                              umount -f $P1
                              umount -f $P2
                              losetup -D
                              exit 1
                              ;;
                         y|Y) BOOT_LABEL="EMMC_BOOT" 
                              while :;do # do level 2
                              read -p "将要重新格式化 ${NEW_BOOT_PATH} 设备,里面的数据将会丢失， 确认吗? y/n " yn2
                              case $yn2 in 
                                  n|N) echo "再见"
                                       umount -f $P1
                                       umount -f $P2
                                       losetup -D
                                       exit 1
                                       ;;
                                  y|Y) if [ "${NEW_BOOT_MOUNTPOINT}" != "" ];then
                                           umount -f ${NEW_BOOT_MOUNTPOINT}
                                           if [ $? -ne 0 ];then
                                                echo "无法卸载 ${NEW_BOOT_MOUNTPOINT}, 再见"
                                                umount -f $P1
                                                umount -f $P2
                                                losetup -D
                                                exit 1
                                           fi
                                       fi
                                       echo "格式化 ${NEW_BOOT_PATH} ..."
                                       mkfs.fat -F 32 -n "${BOOT_LABEL}" ${NEW_BOOT_PATH}

                                       echo "挂载 ${NEW_BOOT_PATH} ->  /mnt/${NEW_BOOT_NAME} ..."
                                       mount ${NEW_BOOT_PATH}  /mnt/${NEW_BOOT_NAME} 
                                       if [ $? -ne 0 ];then
                                           echo "挂载 ${NEW_BOOT_PATH} ->  /mnt/${NEW_BOOT_NAME} 失败!"
                                           umount -f $P1
                                           umount -f $P2
                                           loseup -D
                                           exit 1
                                       fi

                                       echo "复制 /boot ->  /mnt/${NEW_BOOT_NAME} ..."
                                       cp -a  /boot/*  /mnt/${NEW_BOOT_NAME}/

                                       echo "切换 boot ..."
                                       umount -f /boot && \
                                       umount -f /mnt/${NEW_BOOT_NAME}/ && \
                                       mount ${NEW_BOOT_PATH}  /boot
                                       if [ $? -ne 0 ];then
                                           echo "切换失败!"
                                           umount -f $P1
                                           umount -f $P2
                                           loseup -D
                                           exit 1
                                       else
                                           echo "/boot 已切换到 ${NEW_BOOT_PATH}"
				           NEW_BOOT_OK=1
                                       fi
                                       break  # 跳出第2层
                                       ;;
                              esac
                         done # do level 2
                         ;;
                     esac # case $pause
		     if [ $NEW_BOOT_OK -eq 1 ];then
                         BOOT_CHANGED=-1
                         break # 跳出第一层
                     fi
		     ;;
           esac # case $yn1
       done # do level 1
    fi # 当前不在emmc中启动
fi

#format NEW_ROOT
echo "卸载 ${NEW_ROOT_MP}"
umount -f "${NEW_ROOT_MP}"
if [ $? -ne 0 ];then
    echo "卸载失败, 请重启后再试一次!"
    umount -f ${P1}
    umount -f ${P2}
    losetup -D
    exit 1
fi

echo "格式化 ${NEW_ROOT_PATH}"
NEW_ROOT_UUID=$(uuidgen)
mkfs.btrfs -f -U ${NEW_ROOT_UUID} -L ${NEW_ROOT_LABEL} -m single ${NEW_ROOT_PATH}
if [ $? -ne 0 ];then
    echo "格式化 ${NEW_ROOT_PATH} 失败!"
    umount -f ${P1}
    umount -f ${P2}
    losetup -D
    exit 1
fi

echo "挂载 ${NEW_ROOT_PATH} -> ${NEW_ROOT_MP}"
mount -t btrfs -o compress=zstd ${NEW_ROOT_PATH} ${NEW_ROOT_MP}
if [ $? -ne 0 ];then
    echo "挂载 ${NEW_ROOT_PATH} -> ${NEW_ROOT_MP} 失败!"
    umount -f ${P1}
    umount -f ${P2}
    losetup -D
    exit 1
fi

# begin copy rootfs
cd ${NEW_ROOT_MP}
echo "开始复制数据， 从 ${P2} 到 ${NEW_ROOT_MP} ..."
ENTRYS=$(ls)
for entry in $ENTRYS;do
    if [ "$entry" == "lost+found" ];then
        continue
    fi
    echo -n "移除旧的 $entry ... "
    rm -rf $entry 
    if [ $? -eq 0 ];then
        echo "成功"
    else
        echo "失败"
        exit 1
    fi
done
echo

echo -n "创建文件夹 ... "
mkdir -p .reserved bin boot dev etc lib opt mnt overlay proc rom root run sbin sys tmp usr www
ln -sf lib/ lib64
ln -sf tmp/ var
echo "完成"
echo

COPY_SRC="root etc bin sbin lib opt usr www"
echo "复制数据 ... "
for src in $COPY_SRC;do
    echo -n "复制 $src ... "
    (cd ${P2} && tar cf - $src) | tar xf -
    sync
    echo "完成"
done

SHFS="/mnt/mmcblk2p4"
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

rm -f /mnt/${NEW_ROOT_NAME}/root/install-to-emmc.sh
sync
echo "复制完成"
echo

BACKUP_LIST=$(${P2}/usr/sbin/flippy -p)
if [ $BR_FLAG -eq 1 ];then
    # restore old config files
    OLD_RELEASE=$(grep "DISTRIB_REVISION=" /etc/openwrt_release | awk -F "'" '{print $2}'|awk -F 'R' '{print $2}' | awk -F '.' '{printf("%02d%02d%02d\n", $1,$2,$3)}')
    NEW_RELEASE=$(grep "DISTRIB_REVISION=" ./etc/uci-defaults/99-default-settings | awk -F "'" '{print $2}'|awk -F 'R' '{print $2}' | awk -F '.' '{printf("%02d%02d%02d\n", $1,$2,$3)}')
    if [ ${OLD_RELEASE} -le 200311 ] && [ ${NEW_RELEASE} -ge 200319 ];then
            mv ./etc/config/shadowsocksr ./etc/config/shadowsocksr.${NEW_RELEASE}
    fi
    mv ./etc/config/qbittorrent ./etc/config/qbittorrent.orig

    echo -n "开始还原从旧系统备份的配置文件 ... "
    (
      cd /
      eval tar czf ${NEW_ROOT_MP}/.reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null
    )
    tar xzf ${NEW_ROOT_MP}/.reserved/openwrt_config.tar.gz
    if [ ${OLD_RELEASE} -le 200311 ] && [ ${NEW_RELEASE} -ge 200319 ];then
            mv ./etc/config/shadowsocksr ./etc/config/shadowsocksr.${OLD_RELEASE}
            mv ./etc/config/shadowsocksr.${NEW_RELEASE} ./etc/config/shadowsocksr
    fi
    if grep 'config qbittorrent' ./etc/config/qbittorrent; then
        rm -f ./etc/config/qbittorrent.orig
    else
        mv ./etc/config/qbittorrent.orig ./etc/config/qbittorrent
    fi
    sed -e "s/option wan_mode 'false'/option wan_mode 'true'/" -i ./etc/config/dockerman 2>/dev/null
    sed -e 's/config setting/config verysync/' -i ./etc/config/verysync
    sync
    echo "完成"
    echo
fi

echo "修改配置文件 ... "
rm -f "./etc/rc.local.orig" "./usr/bin/mk_newpart.sh" "./etc/part_size"
rm -rf "./opt/docker" && ln -sf "${SHFS}/docker" "./opt/docker"
cat > ./etc/fstab <<EOF
UUID=${NEW_ROOT_UUID} / btrfs compress=zstd 0 1
LABEL=${BOOT_LABEL} /boot vfat defaults 0 2
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
        option label '${BOOT_LABEL}'
        option enabled '1'
        option enabled_fsck '0'
        option fstype 'vfat'
                
EOF

# 2021.04.01添加
# 强制锁定fstab,防止用户擅自修改挂载点
chattr +ia ./etc/config/fstab

rm -f ./etc/bench.log
cat >> ./etc/crontabs/root << EOF
37 5 * * * /etc/coremark.sh
EOF

sed -e 's/ttyAMA0/ttyAML0/' -i ./etc/inittab
sed -e 's/ttyS0/tty0/' -i ./etc/inittab
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
    echo "完成"
    echo
fi
eval tar czf .reserved/openwrt_config.tar.gz "${BACKUP_LIST}" 2>/dev/null

rm -f ./etc/part_size ./usr/bin/mk_newpart.sh
if [ -x ./usr/sbin/balethirq.pl ];then
    if grep "balethirq.pl" "./etc/rc.local";then
        echo "balance irq is enabled"
    else
        echo "enable balance irq"
        sed -e "/exit/i\/usr/sbin/balethirq.pl" -i ./etc/rc.local
    fi
fi
mv ./etc/rc.local ./etc/rc.local.orig

cat > ./etc/rc.local <<EOF
if [ ! -f /etc/rc.d/*dockerd ];then
        /etc/init.d/dockerd enable
        /etc/init.d/dockerd start
fi
mv /etc/rc.local.orig /etc/rc.local
exec /etc/rc.local
exit
EOF

chmod 755 ./etc/rc.local*

cd ${WORK_DIR}
 
echo "开始复制数据， 从 ${P1} 到 /boot ..."
cd /boot
echo -n "删除旧的 boot 文件 ..."
[ -f /tmp/uEnv.txt ] || cp uEnv.txt /tmp/uEnv.txt

rm -rf *
echo "完成"
echo -n "复制新的 boot 文件 ... " 
(cd ${P1} && tar cf - . ) | tar mxf -

if [ "$BOOT_LABEL" == "BOOT" ];then
    [ -f u-boot.ext ] || cp u-boot.emmc u-boot.ext
elif [ "$BOOT_LABEL" == "EMMC_BOOT" ];then
    [ -f u-boot.emmc ] || cp u-boot.ext u-boot.emmc
    rm -f aml_autoscript* s905_autoscript*
    mv -f boot-emmc.ini boot.ini
    mv -f boot-emmc.cmd boot.cmd
    mv -f boot-emmc.scr boot.scr
fi

sync
echo "完成"
echo

echo -n "更新 boot 参数 ... "
if [ -f /tmp/uEnv.txt ];then
    lines=$(wc -l < /tmp/uEnv.txt)
    lines=$(( lines - 1 ))
    head -n $lines /tmp/uEnv.txt > uEnv.txt
    cat >> uEnv.txt <<EOF
APPEND=root=UUID=${NEW_ROOT_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF
elif [ "${CUR_FDTFILE}" != "" ];then
    cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

FDT=${CUR_FDTFILE}

APPEND=root=UUID=${NEW_ROOT_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF
else
    FDT_OK=0
    while [ $FDT_OK -eq 0 ];do
        echo "-----------------------------------------------------------------------------"
	(cd ${P2}/dtb/amlogic && ls *.dtb)
        echo "-----------------------------------------------------------------------------"
        read -p "请手动输入 dtb 文件名: " CUR_FDTFILE
	if [ -f "${P2}/dtb/amlogic/${CUR_FDTFILE}" ];then
            FDT_OK=1
        else
            echo "该 dtb 文件不存在！请重新输入!"
        fi
    done
    cat > uEnv.txt <<EOF
LINUX=/zImage
INITRD=/uInitrd

FDT=${CUR_FDTFILE}

APPEND=root=UUID=${NEW_ROOT_UUID} rootfstype=btrfs rootflags=compress=zstd console=ttyAML0,115200n8 console=tty0 no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory swapaccount=1
EOF
fi

sync
echo "完成"
echo

cd $WORK_DIR
umount -f ${P1} ${P2}
losetup -D
rmdir ${P1} ${P2}

echo
echo "----------------------------------------------------------------------"
if [ $BOOT_CHANGED -gt 0 ];then
    echo "升级已完成, 请不要移除启动用的 TF卡 或 U盘， 然后输入 reboot 命令重启系统!"
elif [ $BOOT_CHANGED -lt 0 ];then
    echo "升级已完成, 请输入 poweroff 命令关闭电源, 然后移除原有的 TF卡 或 U盘， 再启动系统!"
else
    echo "升级已完成, 请输入 reboot 命令重启系统!"
fi
echo "----------------------------------------------------------------------"

