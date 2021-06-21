这是 Flippy 的 Openwrt 打包源码，主要用于制作 Phicomm N1、贝壳云、我家云、微加云、Amlogic S905x3、Amlogic S922x等一系列盒子的 openwrt固件。

一、制作材料：
1. Flippy预编译好的 Arm64 内核 (在 https://t.me/openwrt_flippy  及 https://pan.baidu.com/s/19KNVcCQL57mvpiboFc-5rA 提取码：hk6x )
2. 自己编译的 openwrt rootfs tar.gz 包： openwrt-armvirt-64-default-rootfs.tar.gz 

二、环境准备
1. 需要一台 linux 主机， 可以是 x86或arm64架构，可以是物理机或虚拟机（但不支持win10自带的linux环境），需要具备root权限， 并且具备以下基本命令（只列出命令名，不列出命令所在的包名，因不同linux发行版的软件包名、软件包安装命令各有不同，请自己查询)： 
    losetup、lsblk(版本>=2.33)、blkid、uuidgen、fdisk、parted、mkfs.vfat、mkfs.ext4、mkfs.btrfs (列表不一定完整，打包过程中若发生错误，请自行检查输出结果并添加缺失的命令）
    
2. 需要把 Flippy预编译好的 Arm64 内核上传至 /opt/kernel目录（目录需要自己创建）
3. cd  /opt   
   git clone https://github.com/unifreq/openwrt_packit     
4. 

其它相关信息请参见我在恩山论坛的贴子：

https://www.right.com.cn/forum/thread-981406-1-1.html

https://www.right.com.cn/forum/thread-4055451-1-1.html

https://www.right.com.cn/forum/thread-4076037-1-1.html
