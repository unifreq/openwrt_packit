# 在 KVM 虚拟机中安装使用 OpenWrt 的说明

基于内核的虚拟机 Kernel-based Virtual Machine（KVM）是一种内建于 Linux® 中的开源虚拟化技术。具体而言，KVM 可帮助您将 Linux 转变为虚拟机监控程序，使主机计算机能够运行多个隔离的虚拟环境，即虚拟客户机或虚拟机（VM）。KVM 是 Linux 的一部分，Linux 也是 KVM 的一部分，Linux 有的 KVM 全都有。KVM 的某些特点让它成为了企业的首选虚拟机监控程序，比如在安全性、存储、硬件支持、内存管理、实时迁移、性能和可扩展性、调度和资源控制，以及更低延迟，更高优先级等方面均具有企业级的可靠性。

对于性能过剩的盒子，可以先安装 Armbian 系统，再安装 KVM 虚拟机实现多系统使用。其中 OpenWrt 系统的编译可以使用本仓库的 [mk_qemu-aarch64_img.sh](https://github.com/unifreq/openwrt_packit/blob/master/mk_qemu-aarch64_img.sh) 脚本进行制作，更多系统如 Debian、Ubuntu、OpenSUSE、ArchLinux、Centos、Gentoo、KyLin、UOS 等可在相关网站查阅安装与使用说明。

# 目录

- [在 KVM 虚拟机中安装使用 OpenWrt 的说明](#在-kvm-虚拟机中安装使用-openwrt-的说明)
- [目录](#目录)
  - [1. 物理机安装依赖包](#1-物理机安装依赖包)
  - [2. 安装服务端和客户端](#2-安装服务端和客户端)
    - [2.1 服务端开启 X11Forwarding 功能](#21-服务端开启-x11forwarding-功能)
    - [2.2 安装本地电脑客户端](#22-安装本地电脑客户端)
  - [3. 在物理机中配置网络](#3-在物理机中配置网络)
  - [4. 安装过程截图](#4-安装过程截图)
  - [5. 故障处理](#5-故障处理)
    - [5.1 cpu模式不对](#51-cpu模式不对)
    - [5.2 虚拟机服务未启动](#52-虚拟机服务未启动)
    - [5.3 EFI 启动失败](#53-efi-启动失败)
    - [5.4 桥接网络不通](#54-桥接网络不通)
  - [6. 进阶用法](#6-进阶用法)
    - [6.1 给虚拟机添加第二张网卡](#61-给虚拟机添加第二张网卡)
    - [6.2 给虚拟机添加共享文件系统](#62-给虚拟机添加共享文件系统)
    - [6.3 给虚拟机添加显卡](#63-给虚拟机添加显卡)
    - [6.4 给虚拟机添加直通设备](#64-给虚拟机添加直通设备)
    - [6.5 在命令行下控制虚拟机](#65-在命令行下控制虚拟机)
    - [6.6 虚拟机开机自启](#66-虚拟机开机自启)
    - [6.7 虚拟机双网卡主路由模式拓扑](#67-虚拟机双网卡主路由模式拓扑)
    - [6.8 对于大小核 soc 的特殊设置](#68-对于大小核-soc-的特殊设置)
    - [6.9 物理机性能优化](#69-物理机性能优化)
    - [6.10 物理机针对vhost_net及virtio-net-pci的进一步优化](#610-物理机针对vhost_net及virtio-net-pci的进一步优化)
  - [7. 固件升级](#7-固件升级)
    - [7.1 命令行升级方法](#71-命令行升级方法)
    - [7.2 用晶晨宝盒插件进行升级](#72-用晶晨宝盒插件进行升级)
    - [7.3 双系统切换](#73-双系统切换)
  - [8. 内核升级](#8-内核升级)
    - [8.1 命令行升级方法](#81-命令行升级方法)
    - [8.2 用晶晨宝盒插件进行升级](#82-用晶晨宝盒插件进行升级)
  - [9. 创建自定义尺寸的镜像文件](#9-创建自定义尺寸的镜像文件)

## 1. 物理机安装依赖包

以 Armbian/Debian/ubuntu 为例（其它操作系统请查询对应的命令）。首先验证物理机是否支持 kvm 虚拟化，如果结果如下图，那 kvm 支持就没问题，否则一般是物理机的内核没开启kvm支持（需要重新换个支持kvm的内核），或者是物理机根本就不支持 kvm！按照 arm 的官方文档，cortex-a53 以上的 cpu 都是支持 kvm 的。

```yaml
ls -l /dev/kvm
dmesg | grep kvm
```

<img width="600" src="https://user-images.githubusercontent.com/68696949/180730488-88848d3b-30c6-4c73-9321-4dc64c0c5fc7.png">

在物理机系统中安装 KVM 依赖包(ubuntu jammy)：
```yaml
sudo apt-get install -y gconf2 qemu-system-arm qemu-utils qemu-efi ipxe-qemu libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager seabios vgabios gir1.2-spiceclientgtk-3.0 xauth
```

安装 x11 字库（可选）
```yaml
sudo apt-get install -y fonts-noto*
```

安装桌面环境(可选)
```yaml
sudo apt-get install -y tasksel
```
运行 `tasksel` 命令，选择至少一个桌面环境即可。


对于性能过剩的盒子，可以先安装 Armbian 系统，再安装 KVM 虚拟机实现多系统使用。其中 OpenWrt 系统的编译可以使用本仓库的 mk_qemu-aarch64_img.sh 脚本进行制作，更多系统如 Debian、Ubuntu、OpenSUSE、ArchLinux、Centos、Gentoo、KyLin、UOS 等可在相关网站查阅安装与使用说明。

## 2. 安装服务端和客户端

分别在 Armbian 服务器和本地个人电脑安装服务端和客户端。

### 2.1 服务端开启 X11Forwarding 功能

首先确认远程 Armbian 等服务器上的 SSH 服务端开启了 X11Forwarding 功能：
```yaml
# 编辑 /etc/ssh/sshd_config 文件
X11Forwarding yes
# 如果之前未开启，保存配置文件后重启 sshd
sudo systemctl restart sshd
```

### 2.2 安装本地电脑客户端

运行带桌面环境的 Ubuntu、Debian、Fedora、CentOS 等 Linux 发行版的本地电脑，已经自带X Server，可以略过这一步。Windows、MacOS 系统需要自行下载 X Server 程序：MacOS 可到 https://www.xquartz.org/ 下载 XQuartz 程序，Windows 可到 https://sourceforge.net/projects/vcxsrv/ 下载 VcXsrv，或到 https://sourceforge.net/projects/xming/ 下载 Xming，安装并运行 X Server 程序。

Ssh 客户端是 linux 时，开启 X11 Forwarding 选项，ssh 连接到远程服务器，运行GUI程序：
```yaml
# -X 选项开启X11 Forwarding
ssh -X user@host
# 运行远程 GUI 程序，界面将在本地电脑上显示出来
virt-manager
```

ssh 客户端是 windows 时，ssh 工具可以用 putty、xshell、securecrt 等等，x11 server 可以用 xshell 自带的，或者 xming、vcxsrv、cygwin x11 等。以 securecrt+xming 为例，先双击 Xming 图标，启动之后，图标在右下角（需要防火墙入站规则允许xming）。然后打开 Securecrt session 配置，按图开启 forward x11 选项。接下来，ssh连接到 Armbian 服务器，在#提示符下运行 `virt-manager` 命令，并等待十多秒钟，就会看到虚拟机管理的图形界面了。如下图所示：

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="100" src="https://user-images.githubusercontent.com/68696949/180733567-30aab307-f1ec-4f00-a434-97e12b167a43.png">
<img width="143" src="https://user-images.githubusercontent.com/68696949/180733656-d0e06e97-ddbf-4bbe-8eae-9ddcb45a31ff.png">
<img width="500" src="https://user-images.githubusercontent.com/68696949/180733725-a8494a6f-f144-4750-92ae-7dbd862e327b.png">
</div>

## 3. 在物理机中配置网络

注意：如果物理机只有 1 张网卡的话，要把 eth0 网络改成桥接，以便与虚机共用网卡。以 Armbian/Debian/ubuntu 为例：（其它操作系统请自行查询网桥配置方式）。
`/etc/network/interfaces.d/br0`
```yaml
# eth0 setup
allow-hotplug eth0
iface eth0 inet manual
    pre-up   ifconfig $IFACE up
    pre-down ifconfig $IFACE down

# Bridge setup
auto br0
iface br0 inet static
    bridge_ports eth0
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    address 192.168.3.22
    broadcast 192.168.3.255
    netmask 255.255.255.0
    gateway 192.168.3.1
    dns-nameservers 192.168.3.1
```
物理机有 2 张网卡时，eth1 可以提供给虚拟机做 macvtap 口，但此时物理机自身就不能再使用 eth1 了，需要停用 NetworkManager.service, 并把 eth1 设置为手动:
`/etc/network/interfaces.d/eth1`
```yaml
allow-hotplug eth1
iface eth1 inet manual
  pre-up   ifconfig $IFACE up
  pre-down ifconfig $IFACE down
```
```bash
systemctl restart networking.service
```
如果`NetworkManager.service`是启用状态的话，需要关闭 `NetworkManager.service`
```yaml
systemctl stop NetworkManager.service
systemctl disable NetworkManager.service
init 6
```

## 4. 安装过程截图

`qemu` 的固件镜像后缀是 `.qcow2`，如果下载得到的格式是.7z/.zip/.gz/.xz等，则需要先解压。把镜像上传到物理机的 `/var/lib/libvirt/images/` 目录下，名字可以任意改，如 `openwrt.qcow2` 等。运行 `virt-manager` 命令启动 GUI 图形界面（或桌面环境下点击 `虚拟机管理` 图标）。

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="492" src="https://user-images.githubusercontent.com/68696949/180735265-31a2665a-9dd3-4df3-ab7d-056a58675ca1.png">
<img width="330" src="https://user-images.githubusercontent.com/68696949/180735345-b4a4ba8b-8c71-4d2d-92df-8f4890b23f5c.png">
<img width="304" src="https://user-images.githubusercontent.com/68696949/180735381-2d7861c1-5427-4837-810d-e7defbb4d78d.png">
<img width="606" src="https://user-images.githubusercontent.com/68696949/180735465-00913108-b522-4fd7-8804-da44e2a89375.png">
<img width="304" src="https://user-images.githubusercontent.com/68696949/180735702-68c27590-39bf-4f70-88f7-68fa79d4725a.png">
<img width="301" src="https://user-images.githubusercontent.com/68696949/180735731-25319cfa-f12c-4369-82a7-0d8b8bc030b6.png">
<img width="303" src="https://user-images.githubusercontent.com/68696949/180735750-5e7bf35f-7846-40bb-a610-66873043af0f.png">
<img width="616" src="https://user-images.githubusercontent.com/68696949/180735777-878b7661-22fc-473b-ad72-f64d1dc75b58.png">
<img width="613" src="https://user-images.githubusercontent.com/68696949/180735796-4c825cb8-4f58-4b22-b133-fccc6c966de0.png">
<img width="279" src="https://user-images.githubusercontent.com/68696949/180735816-caa53fef-e4c5-4bb3-ab78-d75d9c4e3e23.png">
<img width="478" src="https://user-images.githubusercontent.com/68696949/180735828-83245491-fcae-4604-b768-aa15975f6584.png">
<img width="439" src="https://user-images.githubusercontent.com/68696949/180735851-525132f6-e856-47a3-9222-08932eaef9fd.png">
<img width="528" src="https://user-images.githubusercontent.com/68696949/180735872-d796073b-5e3e-4c57-a54a-0417aa56285c.png">
<img width="733" src="https://user-images.githubusercontent.com/68696949/180735900-87d6db25-011e-4634-a87c-39b4078ad793.png">
</div>

当虚拟机成功启动之后，即可关闭virt-manager图形窗口，虚拟机仍然在后台运行。第一次运行需要修改虚拟机的ip地址，可以用virsh命令连接到虚拟机的console：
```yaml
virsh console openwrt
```
之后就进入openwrt的shell提示符，就如同在 ssh 或 ttyd 里一样，非常方便！
退出 virsh console 请按 ctrl + ] 快捷键， 即按下ctrl，再按]键。

## 5. 故障处理

常见故障如cpu模式不对、虚拟机服务未启动等解决方法如下。

### 5.1 cpu模式不对

提示 `cpu mode host-mode not supported` ，解决方法：把cpu模式手动改成 `host-passthrough` (如果下拉选项没这个，那就手动输入)，如下图：

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="327" src="https://user-images.githubusercontent.com/68696949/180746369-48be7e51-06b6-47b0-85f7-903bba3fb620.png">
<img width="555" src="https://user-images.githubusercontent.com/68696949/180746402-3aa1ca2f-3ce3-4289-982d-a2f38a8647d0.png">
</div>

### 5.2 虚拟机服务未启动

使用 `sudo systemctl status libvirtd` 命令查看正常情况应该这样：

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="609" src="https://user-images.githubusercontent.com/68696949/180746681-a939b739-6358-43a1-b75c-6608afb451ff.png">
</div>

```yaml
# 如果服务未激活，请手动激活并启动服务
sudo systemctl enable libvirtd
sudo systemctl restart libvirtd
sudo systemctl status libvirtd
```

### 5.3 EFI 启动失败

解决方法：删除虚拟机重建，多试几次，或者给虚拟机改个名，如下图：

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="361" src="https://user-images.githubusercontent.com/68696949/180747104-398b08e0-1036-42c1-9bca-5e0787f28cb5.png">
</div>

###  5.4 桥接网络不通

表现为：虚拟机能ping通主机，主机也能ping通虚拟机，但虚机ping不通外网。

解决方法1：物理机防火墙的默认规则会阻止虚拟机访问外网，标准的解决方案是在物理机的 `/etc/sysctl.conf` 里添加以下内容, 以禁用网桥上的 netfilter：
```yaml
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
```
然后运行 `sysctl  -p`

以上内容参考了 [https://wiki.libvirt.org/page/Net.bridge.bridge-nf-call_and_sysctl.conf](https://wiki.libvirt.org/page/Net.bridge.bridge-nf-call_and_sysctl.conf)

解决方法2: 有另一种方法可以让所有路由桥接 KVM 虚拟机完全不受限制地访问互联网，而无需处理防火墙规则。

默认情况下，所有接口都绑定到公共防火墙区域。但是有多个区域，即`firewall-cmd --list-all-zones`其中一个称为`trusted`，这是一个未过滤的防火墙区域，默认情况下接受所有数据包。因此，您可以将网桥接口绑定到该区域。
```bash
firewall-cmd --remove-interface br0 --zone=public --permanent
firewall-cmd --add-interface br0 --zone=trusted --permanent
firewall-cmd --reload
```

解决方法3: 关闭防火墙服务
```bash
systemctl stop firewalld.service
systemctl disable firewalld.service
```

## 6. 进阶用法

有条件的可以给虚拟机添加第2张网卡等，实现更多玩法，方法如下。

### 6.1 给虚拟机添加第二张网卡

前提是物理机有多余的网卡可用，无论是usb扩展的还是pcie扩展的都行，假设物理机的第二张网卡是eth1，那么：

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="296" src="https://user-images.githubusercontent.com/68696949/180747913-5a91abcb-4b7b-4b4d-901e-4aa42401f851.png">
<img width="621" src="https://user-images.githubusercontent.com/68696949/180747940-0a3c88a0-6c97-4f6b-9882-962145d91122.png">
<img width="385" src="https://user-images.githubusercontent.com/68696949/180747950-9bc2fc02-e886-4c5b-893e-2aaa43a2941f.png">
</div>

新添的网卡要关闭虚拟机之后才会出现，下次启动生效。

### 6.2 给虚拟机添加共享文件系统

此功能可以把物理机的一个文件夹共享给虚拟机使用，实现物理机、虚拟机之间文件共享，或多个虚拟机之间文件共享，非常实用！首先要关闭虚拟机，把内存的shared memory选项打开。

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="487" src="https://user-images.githubusercontent.com/68696949/180748388-fb748fec-064e-4219-a1c1-195f9ca6d7af.png">

然后添加硬件，选择“文件系统”, 驱动程序选择“virtiofs”, 源路径选择物理机上已存在的某个文件夹，目标路径随便编个名字（例如data）

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="603" src="https://user-images.githubusercontent.com/68696949/180748467-21e89096-74b5-4125-b922-97838261ef16.png">
<img width="598" src="https://user-images.githubusercontent.com/68696949/180748504-a172404a-0d5f-4afa-a525-fa5bd85ba47d.png">
</div>

然后启动虚拟机，在虚机中输入命令：
```yaml
mkdir  /mnt/data
mount -t virtiofs data  /mnt/data
df -h
```

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="409" src="https://user-images.githubusercontent.com/68696949/180748646-325bf57e-eca4-4138-b727-ce648a8c5889.png">
</div>

挂载成功，如果想要开机自动挂载的话，可以把挂载命令添加到 `/etc/rc.local` 里。

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="415" src="https://user-images.githubusercontent.com/68696949/180748711-6ee61f7d-9a12-4a63-a6b5-40500f08d8d9.png">
<img width="463" src="https://user-images.githubusercontent.com/68696949/180748739-04b6f7b3-047e-412a-87be-a2d57b046759.png">
</div>

### 6.3 给虚拟机添加显卡

虽然对于openwrt没用，但对于其它linux发行版有用，如果想在armbian里运行另一个linux（debian,ubuntu,openSUSE,archlinux,centos,gentoo,国产麒麟，国产统信uos等等），那这一步是必需的，添加鼠标、键盘、显卡的方法如下：

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="561" src="https://user-images.githubusercontent.com/68696949/180750697-1fb16b9c-b6aa-4fd2-9e5d-b3d41c10eb9b.png">
<img width="644" src="https://user-images.githubusercontent.com/68696949/180750713-af39f21c-990c-49c7-9f4e-b0724110fa86.png">
<img width="645" src="https://user-images.githubusercontent.com/68696949/180750726-496210bc-3b2e-4c3e-a968-39a6070600e6.png">
<img width="618" src="https://user-images.githubusercontent.com/68696949/180750745-da50989a-9b88-4a23-9d25-2f7907a90183.png">
</div>

### 6.4 给虚拟机添加直通设备

这需要物理机支持iommu，一般的电视盒子就别想了，目前即使正规的arm64服务器也很少支持。

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="588" src="https://user-images.githubusercontent.com/68696949/180750914-d4e57bcc-99c4-4a6a-b4db-f80b84984b3e.png">
<img width="607" src="https://user-images.githubusercontent.com/68696949/180750936-3fc34173-1ce6-4a7e-b03c-7e64875db506.png">
<img width="607" src="https://user-images.githubusercontent.com/68696949/180750969-42ac1dbb-4dd3-4111-8734-bca555a4caf6.png">
<img width="265" src="https://user-images.githubusercontent.com/68696949/180751002-ced0eb2b-cd81-424e-bfc3-7490566db620.png">
</div>

如果出现这个提示就是不支持直通。

### 6.5 在命令行下控制虚拟机

用 `virsh` 命令可以对虚拟机进行很多操作。

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="206" src="https://user-images.githubusercontent.com/68696949/180751376-d50fbd96-9687-4094-af3c-e63bf77d9aa4.png">
</div>

```bash
virsh list   # 显示已启动的虚拟机， 如果要显示所有虚机，用 virsh list --all
virsh edit vm_name  # 修改虚拟机的配置文件(/etc/libvirt/qemu/vm_name.xml)，有些更改会立即生效，而大多数更改需关闭虚拟机后才生效，此功能不建议初学者使用
virsh console vm_name # 连接到虚拟机的控制台(/dev/ttyAMA0), 可执行 shell 命令， 类似于 docker exec -it container bash 的功能
virsh start vm_name  # 启动虚拟机
virsh start --console vm_name  # 启动虚拟机，同时连接到虚拟机控制台
virsh reboot vm_name # 重启虚拟机，需要虚拟机中有 acpid 服务的支持，否则此命令无效。 建议在固件底包中加入 acpid
virsh shutdown vm_name  # 正常停止虚拟机，需要虚拟机中有 acpid 服务的支持，否则此命令无效。 建议在固件底包中加入 acpid
virsh destroy vm_name # 强行停止虚拟机
```

### 6.6 虚拟机开机自启

```bash
 virsh autostart vm_name
 vi /etc/default/libvirt-guests
   # set on boot action
   ON_BOOT=start
   # set on shutdown action
   ON_SHUTDOWN=shutdown
 ```
 
<div style="width:100%;margin-top:40px;margin:5px;">
<img width="307" src="https://user-images.githubusercontent.com/68696949/180751674-92a642b2-f8c6-4fad-80ed-1c77d950a7e4.png">
</div>

### 6.7 虚拟机双网卡主路由模式拓扑

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="296" src="https://user-images.githubusercontent.com/68696949/180751788-8de29441-9bfc-4657-a8fa-c860a6db0426.png">
</div>

### 6.8 对于大小核 soc 的特殊设置
注意：在类似于S922X、RK3399这样的大小核物理机下，虚拟机自动重启有一定概率不成功。可能会报如下错误：
  `kvm: kvm_init_vcpu: kvm_arch_init_vcpu failed (0): Invalid argument`

  解决方法：可以手动修改虚拟机控制文件，静态绑定 cpu 核心，示例如下：

  运行 virsh edit vm_name(虚拟机名称)，然后修改 vcpu 小节, 默认：
  ```xml
  <vcpu placement='static'>6</vcpu>
  ```
  改为：
  ```xml
  <vcpu placement='static' cpuset='0-5'>6</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='0'/>
    <vcpupin vcpu='1' cpuset='1'/>
    <vcpupin vcpu='2' cpuset='2'/>
    <vcpupin vcpu='3' cpuset='3'/>
    <vcpupin vcpu='4' cpuset='4'/>
    <vcpupin vcpu='5' cpuset='5'/>
    <emulatorpin cpuset='0-5'/>
  </cputune>
  ```
  假设虚拟机只想分配4核，2小核加2大核（以s922x为例， 0-1 是小核， 2-5是大核)
  ```xml
  <vcpu placement='static' cpuset='0,1,4,5'>4</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='0'/>
    <vcpupin vcpu='1' cpuset='1'/>
    <vcpupin vcpu='2' cpuset='4'/>
    <vcpupin vcpu='3' cpuset='5'/>
    <emulatorpin cpuset='0,1,4,5'/>
  </cputune>
  ```  
  修改完毕之后，要关闭虚拟机才生效。
  
  优化建议：以 GT-King Pro (Amlogic S922X-H 为例）， 保留物理机的 cpu0 不分配，而把 cpu1-5 分配给虚拟机，其配置如下：
  ```xml
  <vcpu placement='static' cpuset='1-5'>5</vcpu>
  <cputune>
    <vcpupin vcpu='0' cpuset='1'/>
    <vcpupin vcpu='1' cpuset='2'/>
    <vcpupin vcpu='2' cpuset='3'/>
    <vcpupin vcpu='3' cpuset='4'/>
    <vcpupin vcpu='4' cpuset='5'/>
    <emulatorpin cpuset='1-5'/>
  </cputune>
  ```
  本节内容参考了 [华为云: 虚拟机绑核](https://support.huaweicloud.com/tngg-kunpengcpfs/kunpengkvm_05_0008.html#:~:text=vcpu%20placement%20%3D%20%27static%27,cpuset%3D%274-7%27%EF%BC%9A%E7%94%A8%E4%BA%8EIO%E7%BA%BF%E7%A8%8B%E3%80%81worker%20threads%E7%BA%BF%E7%A8%8B%E4%BB%85%E8%83%BD%E4%BD%BF%E7%94%A84-7%E8%BF%994%E4%B8%AA%E6%A0%B8%EF%BC%8C%E8%8B%A5%E4%B8%8D%E9%85%8D%E7%BD%AE%E6%AD%A4%E5%8F%82%E6%95%B0%EF%BC%8C%E8%99%9A%E6%8B%9F%E6%9C%BA%E4%BB%BB%E5%8A%A1%E7%BA%BF%E7%A8%8B%E4%BC%9A%E5%9C%A8CPU%E4%BB%BB%E6%84%8Fcore%E4%B8%8A%E6%B5%AE%E5%8A%A8%EF%BC%8C%E4%BC%9A%E5%AD%98%E5%9C%A8%E6%9B%B4%E5%A4%9A%E7%9A%84%E8%B7%A8NUMA%E5%92%8C%E8%B7%A8DIE%E6%8D%9F%E8%80%97%E3%80%82%20vcpupin%E7%94%A8%E4%BA%8E%E9%99%90%E5%88%B6%E5%AF%B9CPU%E7%BA%BF%E7%A8%8B%E5%81%9A%E4%B8%80%E5%AF%B9%E4%B8%80%E7%BB%91%E6%A0%B8%E3%80%82%20%E8%8B%A5%E4%B8%8D%E4%BD%BF%E7%94%A8vcpupin%E7%BB%91CPU%E7%BA%BF%E7%A8%8B%EF%BC%8C%E5%88%99%E7%BA%BF%E7%A8%8B%E4%BC%9A%E5%9C%A84-7%E8%BF%99%E4%B8%AA4%E4%B8%AA%E6%A0%B8%E4%B9%8B%E9%97%B4%E5%88%87%E6%8D%A2%EF%BC%8C%E9%80%A0%E6%88%90%E9%A2%9D%E5%A4%96%E5%BC%80%E9%94%80%E3%80%82)

### 6.9 物理机性能优化
 
运行 armbian-config， 选择 system -> cpu -> minfreq -> maxfreq -> governor ( 建议选择 schedutil ) 

另外， 对于一般的arm64 soc，采用内置网卡或usb网卡时，通常会挤占cpu0, 导致整体网络性能不佳（如果网卡是 pcie 接口，并且支持 rss 多队列的话则不存在此问题）
  
armbian 有一个系统服务： armbian-hardware-optimize.service ， 可以对 softirq 等进行一些必要的优化，可以选择开启：
```bash
systemctl status armbian-hardware-optimize.service 
systemctl enable armbian-hardware-optimize.service
systemctl start armbian-hardware-optimize.service
```
  
如果 armbian-hardware-optimize.service 没有达到预期效果，或是没采用 armbian的话，可以用我写的脚本： [balethirq.pl](/files/balethirq.pl) + [配置文件：balance_irq demo](/files/s922x/balance_irq):
```bash
cp   balethirq.pl  /usr/sbin

# 创建 /etc/balance_irq， 进行中断配置，简而言之就是把两张网卡产生的中断分散到两个cpu里（默认情况下是共用第1个cpu)
# 设备名称(devname)  cpu亲和性(cpu affinity)
vi  /etc/balance_irq
eth0 1
xhci-hcd:usb1 6
```
  
balance_irq配置参考：
```bash
root@gtking-pro:~# cat /proc/interrupts 
           CPU0       CPU1       CPU2       CPU3       CPU4       CPU5       
  9:          0          0          0          0          0          0     GICv2  25 Level     vgic
 11:   17580788   33822531   34847277   34198393   34319935   34518922     GICv2  30 Level     arch_timer
 12:          0     229777     183235     217133     194856     188719     GICv2  27 Level     kvm guest vtimer
 14:          0          0          0     640860          0          0     GICv2  40 Level     eth0
 15:         15          0          0          0          0          0     GICv2  89 Edge      dw_hdmi_top_irq, ff600000.hdmi-tx
 21:          0          0          0          0          0          0     GICv2 235 Edge      ff800280.cec
 22:         40          0          0          0          0          0     GICv2 225 Edge      ttyAML0
 23:          8          0          0          0          0          0     GICv2 228 Edge      ff808000.ir
 24:          0          0          0          0          0          0     GICv2  76 Edge      vdec
 25:          0          0          0          0          0          0     GICv2  64 Edge      esparserirq
 26:        314          0          0          0          0          0     GICv2  35 Edge      meson
 27:       1126          0          0          0          0          0     GICv2  71 Edge      ffd1c000.i2c
 28:       4778          0          0          0          0          0     GICv2  58 Edge      ttyAML6
 29:    3468797          0          0          0          0          0     GICv2 221 Edge      ffe03000.sd
 30:          0          0          0          0          0          0     GICv2 222 Edge      ffe05000.sd
 31:       5233      91355          0          0          0          0     GICv2 223 Edge      ffe07000.mmc
 33:          0          0          0          0          0          0     GICv2 194 Level     panfrost-job
 34:          0          0          0          0          0          0     GICv2 193 Level     panfrost-mmu
 35:          4          0          0          0          0          0     GICv2 192 Level     panfrost-gpu
 36:          0          0          0          0          0          0     GICv2  63 Level     ff400000.usb, ff400000.usb
 37:        535          0    3031088          0          0          0     GICv2  62 Level     xhci-hcd:usb1
 38:          1          0          0          0          0          0  meson-gpio-irqchip  26 Level     mdio_mux-0.0:00
IPI0:    113124     140214    3226181     993988    1235145    1329681       Rescheduling interrupts
IPI1:     66072     703466     282906     331811    3737960     332876       Function call interrupts
IPI2:         0          0          0          0          0          0       CPU stop interrupts
IPI3:         0          0          0          0          0          0       CPU stop (for crash dump) interrupts
IPI4:         0          0          0          0          0          0       Timer broadcast interrupts
IPI5:      3761      15984     378310     823397    1323761     923798       IRQ work interrupts
IPI6:         0          0          0          0          0          0       CPU wake-up interrupts
Err:          0  
```
需要注意到两张网卡： 内置网卡`eth0`，以及外置网卡（USB RTL8153)， 表现为 `xhci-hcd:usb1`

在上例的 `balance_irq` 里， `eth0 -> cpu1`     `xhci-hcd:usb1 -> cpu6`  在这里，cpu编号是从1开始，而不是从0开始
  
最后，把 `/usr/sbin/balethirq.pl`  添加到  `/etc/rc.local` 里以实现开机启动。
```bash
root@gtking-pro:~# cat /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

/usr/sbin/balethirq.pl
exit 0
```
  
```bash
root@gtking-pro:~# balethirq.pl 
irq name:eth0, irq:14, affinity: 1
irq name:xhci-hcd:usb1, irq:37, affinity: 20
Set the rps cpu mask of eth0 to 0x1e
Set the rps cpu mask of eth1 to 0x1e
```
### 6.10 物理机针对vhost_net及virtio-net-pci的进一步优化
KVM虚拟机采用virtio-net-pci半虚拟化网卡驱动，在虚拟机中装载virtio_net模块，而在物理机中装载vhost_net模块。

1. 使用多队列 virtio-net (即虚拟网卡开启rss)，通过向虚拟机 XML 配置 queues='N'（最多可以与vcpu数量相等，建议从 N=2 开始尝试），运行`virsh edit vm_name`：
```xml
<interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <driver name='vhost' queues='N'/>
</interface>
```
本节参考了 [虚拟化调试和优化指南](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html-single/virtualization_tuning_and_optimization_guide/index#sect-Virtualization_Tuning_Optimization_Guide-Networking-Multi-queue_virtio-net)

2. 启用打包的虚拟队列

传统上，Virtio 在主机和虚拟机之间共享拆分队列。Packed virtqueues 是另一种紧凑的 virtqueue 布局，主机和来宾都可以读取和写入，在性能方面更有效。运行`virsh edit vm_name`
```xml
<interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <driver name='vhost' packed='on'/>
</interface>
```
本节参考了[基于第三代英特尔® 至强® 可扩展处理器的平台上的 KVM/Qemu 虚拟化调整指南](https://www.intel.cn/content/www/cn/zh/developer/articles/guide/kvm-tuning-guide-on-xeon-based-systems.html)
  
本节和上节的方案可以联合使用，即：
```xml
<interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
      <driver name='vhost' queues='N' packed='on'/>
</interface>
```  
  
3. 启用 vhost-net 零拷贝

零复制传输（Bridge Zero Copy Transmit）模式对于大尺寸的数据包较为有效。通常在客机网络和外部网络间的大数据包传输中，它对主机 CPU 负荷的减少可达到 15%，对吞吐量没有影响。
它不对客机到客机、客机到主机或小数据包负载造成影响。
   
在 Linux 中，默认禁用 vhost-net 零拷贝。要永久启用此操作，请添加一个包含以下内容 vhost-net.conf 的新文件：/etc/modprobe.d/vhost-net.conf
```
options vhost_net  experimental_zcopytx=1
```
然后重启系统，验证零拷贝是否开启:
```bash
cat /sys/module/vhost_net/parameters/experimental_zcopytx 
```
值为1则启用，为0则未启用
 
本节参考了 [虚拟化调试和优化指南](https://access.redhat.com/documentation/zh-cn/red_hat_enterprise_linux/7/html-single/virtualization_tuning_and_optimization_guide/index#sect-Virtualization_Tuning_Optimization_Guide-Networking-Multi-queue_virtio-net)
  
## 7. 固件升级

每次固件发布会有2个文件, 例如：`openwrt_qemu-aarch64_generic_R22.7.7_k5.18.15-flippy-75+_update.img` 和 `openwrt_qemu-aarch64_R22.7.7_k5.18.15-flippy-75+.qcow2`
其中，后缀为.qcow2的文件是首次创建虚拟机用的，而另一个后缀为.img的文件就用于升级的。

### 7.1 命令行升级方法

把 openwrt_qemu-aarch64_generic_vm_k5.18.13-flippy-75+.img 及附带的升级脚本上传至虚拟机的 `/mnt/vda4` 目录下（7z压缩包里也会同时包含一个升级脚本：update-kvm-openwrt.sh，与/usr/sbin/openwrt-update-kvm是同一个文件，但版本可能更新一些）

```yaml
cd /mnt/vda4
/usr/sbin/openwrt-update-kvm  openwrt_qemu-aarch64_generic_vm_k5.18.13-flippy-75+.img
# 或者
./update-kvm-openwrt.sh openwrt_qemu-aarch64_generic_vm_k5.18.13-flippy-75+.img
```

### 7.2 用晶晨宝盒插件进行升级

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="770" src="https://user-images.githubusercontent.com/68696949/180752372-e4437e37-714e-48cc-ae39-ed203662f139.png">
<img width="730" src="https://user-images.githubusercontent.com/68696949/180752383-d5e9cba6-d932-41fa-af4a-648fca5d5cab.png">
</div>

### 7.3 双系统切换

现在终于有后悔药可以吃了，送你个无敌风火轮...

<div style="width:100%;margin-top:40px;margin:5px;">
<img width="759" src="https://user-images.githubusercontent.com/68696949/180752551-8902d6af-2bf7-4847-a478-cd06c6a67ffd.png">
</div>


## 8. 内核升级

内核升级即：只升级kernel，不升级openwrt的应用。

### 8.1 命令行升级方法

把 `boot-xxxx.tar.gz`、`modules-xxxx.tar.gz`两个内核压缩包上传至 `/mnt/vda4`, 然后运行：`openwrt-kernel-kvm`

### 8.2 用晶晨宝盒插件进行升级

使用方法基本与 7.2 相同

## 9. 创建自定义尺寸的镜像文件
  
  默认的img镜像是 1057MB(SKIP_MB=16 BOOT_MB=16 ROOTFS_MB=1024 TAIL_MB=1,  16+16+1024+1=1057), 包括 efi + rootfs1 等2个分区；
  
  默认的qcow2镜像，由于是动态分配，其初始尺寸比较小(<1057MB)，但实际在虚拟机中的磁盘容量却很大(默认是 16385MB, QCOW2_MB="+15328M", 1057+15328=16385)，且包含4个分区(efi + rootfs1 + rootfs2 + share), 在使用过程中，qcow2 占用物理机磁盘的空间会逐渐变大，直至撑满16385MB的最大尺寸。
                                            
  在使用 mk_qemu-aarch64_img.sh 创建镜像时，可以自定义分区尺寸以符合个性化需求， 一般情况下可以修改 ROOTFS_MB(略大于 rootfs + kernel 解压以后所占的空间 * 0.6 即可，btrfs + zstd 压缩率大约是 40-50% )及 QCOW2_MB 两个变量， 例如：
```bash
ROOTFS_MB=640 QCOW2_MB="+2048M" ./mk_qemu-aarch64_img.sh 
```
上述命令可创建出 16+16+640+1=673MB 的 img 镜像，以及 673+2048=2721MB 的 qcow2 镜像， 在qcow2镜像中，4个分区尺寸分别为： 16MB、640MB、640MB、1408MB
