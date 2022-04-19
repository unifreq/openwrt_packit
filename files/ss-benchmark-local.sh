#!/bin/bash

# 测试文件默认内存的 1/4，放在/tmp(内存)下面，请事先确认空间是否足够
free_mem=$(df -m /tmp | tail -1 | awk '{print $2}')
bin_size=$((free_mem / 4))

function create_test_json() {
    local jsonfile=$1
    local method=$2
    cat > $jsonfile <<EOF
{
    "server" : "127.0.0.1",
    "mode" : "tcp_only",
    "server_port": 8388,
    "local_port": 1080,
    "password" : "password",
    "timeout": 60,
    "method" : "${method}"
}
EOF
}

BIN_HOME=/usr/bin
WWW_HOME=/www

SS_SERVER=${BIN_HOME}/ss-server
SS_LOCAL=${BIN_HOME}/ss-local
SS_VERSION="glibc"
echo -e "\033[1m有多个版本的 shadowsocks, 请问要测试哪一个版本？\033[0m"
cat <<EOF
    ----------------------------------------------------------------------------------
      1. ${BIN_HOME}/ss-server + ${BIN_HOME}/ss-local (glibc version)
EOF
if [ -f ${BIN_HOME}/ss-bin-musl/ss-server ] && [ -f ${BIN_HOME}/ss-bin-musl/ss-local ];then
    cat <<EOF
      2. ${BIN_HOME}/ss-bin-musl/ss-server + ${BIN_HOME}/ss-bin-musl/ss-local (musl version)
EOF
fi
if [ -f ${BIN_HOME}/ssserver ] && [ -f ${BIN_HOME}/sslocal ];then
    cat <<EOF
      3. ${BIN_HOME}/ssserver + ${BIN_HOME}/sslocal (rust version)
    ----------------------------------------------------------------------------------
EOF
fi
echo -ne "     [1]\b\b"

    read select
    case $select in 
	    2) SS_SERVER=${BIN_HOME}/ss-bin-musl/ss-server
	       SS_LOCAL=${BIN_HOME}/ss-bin-musl/ss-local
	       SS_VERSION="musl"
	       ;;
	    3) SS_SERVER=${BIN_HOME}/ssserver
	       SS_LOCAL=${BIN_HOME}/sslocal
	       SS_VERSION="rust"
	       ;;
    esac


if [ "${select}" == "3" ];then
	methods="aes-128-gcm aes-256-gcm chacha20-ietf-poly1305"
else
    cat <<EOF
    ----------------------------------------------------------------------------------
      1. 精简版测试 (5 种算法)
      2. 完整版测试 (15 种算法)
    ----------------------------------------------------------------------------------
EOF
echo -ne "     [1]\b\b"

    read select
    case $select in 
	    2) methods="
		    aes-128-cfb
		    aes-128-ctr
		    aes-128-gcm
		    aes-192-cfb
		    aes-192-ctr
		    aes-192-gcm
		    aes-256-cfb
		    aes-256-ctr
		    aes-256-gcm
		    salsa20
		    chacha20
		    chacha20-ietf
		    chacha20-ietf-poly1305
                    xchacha20-ietf-poly1305
		    rc4-md5"
		;;
	    *) methods="aes-128-gcm
		    aes-192-gcm
		    aes-256-gcm
		    chacha20-ietf-poly1305
		    rc4-md5"
		;;
    esac
fi

echo "creating a ${bin_size}MB test file ... "
mkdir -p /tmp/test ${WWW_HOME}/test
dd if=/dev/urandom of=/tmp/test/test.bin bs=1M count=$bin_size
#dd if=/dev/zero of=/tmp/test/test.bin bs=1M count=$bin_size
mount -o bind /tmp/test ${WWW_HOME}/test
echo "done"
echo 

retfile=$(mktemp)
echo " benchmark begin ... "
echo "==============================================================================="
for method in $methods;do
    echo 
    echo "-------------->>>>>>>>>>>>>  method: $method"
    echo "start ss-server ... "
    create_test_json "/tmp/ss_test.json" "${method}"
    $SS_SERVER -c /tmp/ss_test.json &
    PID1=$!
    sleep 1
    echo
    echo "start ss-local ... "
    $SS_LOCAL -c /tmp/ss_test.json &
    PID2=$!
    sleep 2
    echo
    echo -n "start curl download benchmark ... "
    curltmp=$(mktemp)
    curl --socks5 127.0.0.1 http://localhost/test/test.bin --output /dev/null 2>$curltmp
    if [ $? -eq 0 ];then
	echo "ok"
	echo "--------------------------------------------------------------------------------"
	cat $curltmp | tr '\r' '\n'
	echo "--------------------------------------------------------------------------------"
	perf=$(cat $curltmp | tr '\r' '\n' | tail -n1 | tr -d 'M' | awk '{printf("%0.1fMB/s\n",$7)}')
        printf "%-25s->%12s\n" "$method" "$perf" >> $retfile
    else
	echo "failed!"

    fi
    rm -f $curltmp
    kill $PID1 $PID2 2>/dev/null
    echo
    sleep 1
done
echo "==============================================================================="
echo " benchmark end"
echo

while umount ${WWW_HOME}/test 2>/dev/null;do
    echo -n "umount ${WWW_HOME}/test ... "
done
echo "done"
echo -n "cleaning test file ... "
rm -rf /tmp/test ${WWW_HOME}/test
echo "done"
echo
echo
echo " <<<  The benchmark result report  >>>" 
echo "+++++++++++++++++++++++++++++++++++++++"
cat $retfile
rm -f $retfile
echo "+++++++++++++++++++++++++++++++++++++++"
echo "ss version: [$SS_VERSION]"
model="unknown"
arch=$(uname -m)
if [ "$arch" == "aarch64" ];then
    model=$(cat /proc/device-tree/model |tr -d '\000')
elif [ "$arch" == "x86_64" ];then
    model=$(cat /proc/cpuinfo | grep 'model name' | uniq | awk -F':' '{print $2}') 
fi
echo "model: [$model]"
kernel=$(uname -r)
echo "kernel: [$kernel]"
echo "注意： 以上结果仅用于评估单核性能，不代表实际网速"
echo
