# Github Actions 打包脚本使用说明

支持一键打包目前已经支持的全部 OpenWrt 固件，如贝壳云、我家云、微加云，以及 Amlogic S9xxx 系列型号如 s922x、s905x3、s905x2、s905d，s905，s912 等。

## 使用方法

在 `.github/workflows/*.yml` 云编译脚本中引入此 Actions 即可进行打包，代码如下：

```yaml

- name: Package Armvirt as OpenWrt
  uses: unifreq/openwrt_packit@master
  env:
    OPENWRT_ARMVIRT: openwrt/bin/targets/*/*/*.tar.gz
    PACKAGE_SOC: s905d_s905x3_beikeyun
    KERNEL_VERSION_NAME: 5.13.2_5.4.132

```

打包好的固件在 ${{ env.PACKAGED_OUTPUTPATH }}/* ，可以上传至 Releases 等处，代码如下：

```yaml

- name: Upload OpenWrt Firmware to Releases
  uses: softprops/action-gh-release@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    tag_name: openwrt_armvirt_${{ env.PACKAGED_OUTPUTDATE }}
    files: ${{ env.PACKAGED_OUTPUTPATH }}/*
    body: |
      This is OpenWrt firmware for Armvirt 64
      * Firmware information
      Default IP: 192.168.1.1
      Default username: root
      Default password: password

```

## 可选参数说明

可以对 `打包文件`、`make.env`、`选择内核版本`、`选择盒子SoC` 等参数进行个性化配置。

| 参数                   | 默认值                  | 说明                                            |
|------------------------|------------------------|------------------------------------------------|
| OPENWRT_ARMVIRT_PATH   | no                     | 必选项. 设置 `openwrt-armvirt-64-default-rootfs.tar.gz` 的文件路径，可以使用相对路径如 `openwrt/bin/targets/*/*/*.tar.gz` 或 网络文件下载地址如 `https://github.com/*/releases/*/openwrt-armvirt-64-default-rootfs.tar.gz` |
| KERNEL_REPO_URL        | [breakings/.../kernel](openwrt_flippy.sh#L23) | 设置内核下载地址，默认从 breakings 维护的 [kernel](https://github.com/breakings/OpenWrt/tree/main/opt/kernel) 库里下载 Flippy 的内核。 |
| KERNEL_VERSION_NAME    | 5.13.2_5.4.132         | 设置内核版本，[kernel](https://github.com/breakings/OpenWrt/tree/main/opt/kernel) 库里收藏了众多 Flippy 的原版内核，可以查看并选择指定。可指定单个内核如 `5.4.132` ，可选择多个内核用`_`连接如 `5.13.2_5.4.132` ，内核名称以 kernel 目录中的文件夹名称为准。 |
| KERNEL_AUTO_LATEST     | true                   | 设置是否自动采用同系列最新版本内核。当为 `true` 时，将自动在内核库中查找在 `KERNEL_VERSION_NAME` 中指定的内核如 5.13.2 的 5.13 同系列是否有更新的版本，如有 5.13.3 及之后的最新版本时，将自动更换为最新版。设置为 `false` 时将编译指定版本内核。 |
| PACKAGE_SOC            | s905d_s905x3_beikeyun  | 设置打包盒子的 `SOC` ，默认 `all` 打包全部盒子，可指定单个盒子如 `s905x3` ，可选择多个盒子用`_`连接如 `s905x3_s905d` 。各盒子的SoC代码为：`vplus` `beikeyun` `l1pro` `s905` `s905d` `s905x2` `s905x3` `s912` `s922x` |
| GZIP_IMGS              | true                   | 设置打包完毕是否自动压缩为 .img.gz 文件 (压缩包上传下载更快) |
| SCRIPT_VPLUS           | mk_h6_vplus.sh         | 设置打包 `h6 vplus` 的脚本文件名                 |
| SCRIPT_BEIKEYUN        | mk_rk3328_beikeyun.sh  | 设置打包 `rk3328 beikeyun` 的脚本文件名          |
| SCRIPT_L1PRO           | mk_rk3328_l1pro.sh     | 设置打包 `rk3328 l1pro` 的脚本文件名             |
| SCRIPT_S905            | mk_s905_mxqpro+.sh     | 设置打包 `s905 mxqpro+` 的脚本文件名             |
| SCRIPT_S905D           | mk_s905d_n1.sh         | 设置打包 `s905d n1` 的脚本文件名                 |
| SCRIPT_S905X2          | mk_s905x2_x96max.sh    | 设置打包 `s905x2 x96max` 的脚本文件名            |
| SCRIPT_S905X3          | mk_s905x3_multi.sh     | 设置打包 `s905x3 multi` 的脚本文件名             |
| SCRIPT_S912            | mk_s912_zyxq.sh        | 设置打包 `s912 zyxq` 的脚本文件名                |
| SCRIPT_S022X           | mk_s922x_gtking.sh     | 设置打包 `s922x gtking` 的脚本文件名             |
| WHOAMI                 | flippy                 | 设置 `make.env` 中 `WHOAMI` 参数的值            |
| OPENWRT_VER            | auto                   | 设置 `make.env` 中 `OPENWRT_VER` 参数的值。默认 `auto` 将自动继承文件中的赋值，设置为其他参数时将替换为自定义参数。 |
| SW_FLOWOFFLOAD         | 1                      | 设置 `make.env` 中 `SW_FLOWOFFLOAD` 参数的值    |
| HW_FLOWOFFLOAD         | 0                      | 设置 `make.env` 中 `HW_FLOWOFFLOAD` 参数的值    |
| ENABLE_WIFI_K504       | 1                      | 设置 `make.env` 中 `ENABLE_WIFI_K504` 参数的值  |
| ENABLE_WIFI_K510       | 0                      | 设置 `make.env` 中 `ENABLE_WIFI_K510` 参数的值  |

## 输出参数说明

根据 github.com 的标准输出了 3 个变量，方便编译步骤后续使用。

| 参数                            | 默认值                  | 说明                       |
|--------------------------------|-------------------------|---------------------------|
| ${{ env.PACKAGED_OUTPUTPATH }} | /opt/openwrt_packit/tmp | 打包后的固件所在文件夹的路径  |
| ${{ env.PACKAGED_OUTPUTDATE }} | 2021.08.25.1058         | 打包日期                    |
| ${{ env.PACKAGED_STATUS }}     | success / failure       | 打包状态。成功 / 失败        |

## OpenWrt 固件个性化定制说明

此 `Actions` 仅提供 OpenWrt 打包服务，你需要自己编译 `openwrt-armvirt-64-default-rootfs.tar.gz`。

