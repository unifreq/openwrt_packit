#!/bin/bash

# 用法：
# 本机必须安装并运行docker服务
# 把编译好的　openwrt-armvirt-64-default-rootfs.tar.gz 放到 ./src2/，或./, 再运行本脚本
#
# 脚本可以代入2个参数：　          [img_name]              [tag]
# 例如：./mk_openwrt_dockerimg.sh  myname/openwrt-aarch64  latest
# 如果不填命令行参数的话，默认镜像名称是　unifreq/openwrt-aarch64:latest
#
# build成功后，用 docker images可以看到生成的镜像
# 并且会打包成本地镜像： ${OUTDIR}/docker-img-openwrt-aarch64-${TAG}.gz (可以用docker loader 命令导入)

IMG_NAME=unifreq/openwrt-aarch64
TAG=latest
if [ ! -z "$1" ];then
    IMG_NAME=$1
    if [ ! -z "$2" ];then
        TAG=$2
    fi
fi

WORKDIR=${PWD}

if [ -f ${WORKDIR}/src2/openwrt-armvirt-64-default-rootfs.tar.gz ];then
    SRC_IMG=${WORKDIR}/src2/openwrt-armvirt-64-default-rootfs.tar.gz
else
    SRC_IMG=${WORKDIR}/openwrt-armvirt-64-default-rootfs.tar.gz
fi

if [ ! -f ${SRC_IMG} ];then
    echo "Source image is not exists: ${SRC_IMG}"
    exit 1
fi

TMPDIR=${PWD}/openwrt_docker_rootfs
OUTDIR=${PWD}/output
[ -d "$OUTDIR" ] || mkdir -p ${OUTDIR}

[ -d "$TMPDIR" ] && rm -rf "$TMPDIR" 
mkdir -p "$TMPDIR" && gzip -dc ${SRC_IMG} | ( cd "$TMPDIR" && tar xf - && rm -rf ./lib/firmware/* && rm -rf ./lib/modules/*)

[ -x $TMPDIR/bin/bash ] && \
	cp -f files/docker/30-sysinfo.sh $TMPDIR/etc/profile.d/ && \
	sed -e "s/\/bin\/ash/\/bin\/bash/" -i $TMPDIR/etc/passwd && \
	sed -e "s/\/bin\/ash/\/bin\/bash/" -i $TMPDIR/usr/libexec/login.sh

[ -f files/banner ] && \
	cp -f files/banner $TMPDIR/etc/ && \
	echo "The docker aarch64 special edition" >> $TMPDIR/etc/banner && \
	echo "" >> $TMPDIR/etc/banner

cat >> $TMPDIR/etc/sysupgrade.conf <<EOF
/etc/ssh/ssh_host_ed25519_key
/etc/ssh/ssh_host_ed25519_key.pub
/etc/ssh/ssh_host_rsa_key
/etc/ssh/ssh_host_rsa_key.pub
/root/.ssh/
EOF

cp -f files/docker/rc.local "$TMPDIR/etc/" && \
cp -f files/99-custom.conf "$TMPDIR/etc/sysctl.d/" && \
cp -f files/cpustat "$TMPDIR/usr/bin/" && chmod 755 "$TMPDIR/usr/bin/cpustat" && \
cp -f files/getcpu "$TMPDIR/bin/" && chmod 755 "$TMPDIR/bin/getcpu" && \
cp -f files/coremark.sh "$TMPDIR/etc/" && chmod 755 "$TMPDIR/etc/coremark.sh"
cp -f files/kmod "$TMPDIR/sbin/" && \
	(
            cd $TMPDIR/sbin && \
		 chmod 755 kmod && \
                 rm insmod lsmod modinfo modprobe rmmod && \
		 ln -s kmod insmod && \
		 ln -s kmod lsmod && \
		 ln -s kmod modinfo && \
		 ln -s kmod modprobe && \
		 ln -s kmod rmmod 
	)

cat files/luci-admin-status-index-html.patch | (cd "$TMPDIR/" && patch -p1) && \
	cat files/luci-admin-status-index-html-02.patch | (cd "$TMPDIR/" && patch -p1)

cat files/docker/init.d_turboacc.patch | (cd "$TMPDIR/" && patch -p1 )
if ! cat files/docker/cbi_turboacc_new.patch | (cd "$TMPDIR/" && patch -p1 );then
    cat files/docker/cbi_turboacc.patch | (cd "$TMPDIR/" && patch -p1 )
    ( find "$TMPDIR" -name '*.rej' -exec rm {} \; 
      find "$TMPDIR" -name '*.orig' -exec rm {} \;
    )
fi
sed -e "s/hw_flow '1'/hw_flow '0'/" -i $TMPDIR/etc/config/turboacc
sed -e "s/sfe_flow '1'/sfe_flow '0'/" -i $TMPDIR/etc/config/turboacc

rm -f "$TMPDIR/etc/bench.log" && \
echo "17 3 * * * /etc/coremark.sh" >> "$TMPDIR/etc/crontabs/root"

[ -f ${TMPDIR}/etc/config/qbittorrent ] && sed -e 's/\/opt/\/etc/' -i "${TMPDIR}/etc/config/qbittorrent"

[ -f ${TMPDIR}/etc/ssh/sshd_config ] && sed -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" -i "${TMPDIR}/etc/ssh/sshd_config"

[ -f ${TMPDIR}/etc/samba/smb.conf.template ] && cat patches/smb4.11_enable_smb1.patch | (cd "$TMPDIR" && [ -f etc/samba/smb.conf.template ] && patch -p1)

sss=$(date +%s) && \
ddd=$((sss/86400)) && \
sed -e "s/:0:0:99999:7:::/:${ddd}:0:99999:7:::/" -i "${TMPDIR}/etc/shadow" && \
sed -e "s/root::/root:\$1\$0yUsq67p\$RC5cEtaQpM6KHQfhUSIAl\.:/" -i "${TMPDIR}/etc/shadow"

(cd "$TMPDIR" && tar cf ../openwrt-armvirt-64-default-rootfs-patched.tar .) && \
if [ `uname -i` == "aarch64" ];then
    # native platform build
    rm -f DockerImg-OpenwrtArm64-${TAG}.gz && \
    docker build -t ${IMG_NAME}:${TAG} . && \
    rm -f  openwrt-armvirt-64-default-rootfs-patched.tar && \
    rm -rf "$TMPDIR" && \
    docker save ${IMG_NAME}:${TAG} | pigz -9 > $OUTDIR/docker-img-openwrt-aarch64-${TAG}.gz
else
    # cross platform build
    rm -f DockerImg-OpenwrtArm64-${TAG}.gz && \
    DOCKER_BUILDKIT=1 docker build --platform=linux/arm64 -t ${IMG_NAME}:${TAG} . && \
    rm -f  openwrt-armvirt-64-default-rootfs-patched.tar && \
    rm -rf "$TMPDIR" && \
    docker save ${IMG_NAME}:${TAG} | pigz -9 > $OUTDIR/docker-img-openwrt-aarch64-${TAG}.gz
fi
