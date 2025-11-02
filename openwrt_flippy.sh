#!/usr/bin/env bash
#==============================================================================================
#
# Description: Automatically Packaged OpenWrt
# Function: Use Flippy's kernrl files and script to Packaged openwrt
# Copyright (C) 2021 https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021 https://github.com/ophub/flippy-openwrt-actions
#
#======================================= Functions list =======================================
#
# error_msg         : Output error message
# init_var          : Initialize all variables
# init_packit_repo  : Initialize packit openwrt repo
# query_kernel      : Query the latest kernel version
# check_kernel      : Check kernel files integrity
# download_kernel   : Download the kernel
# make_openwrt      : Loop to make OpenWrt files
# out_github_env    : Output github.com variables
#
#=============================== Set make environment variables ===============================
#
# Set the default package source download repository
SCRIPT_REPO_URL_VALUE="https://github.com/unifreq/openwrt_packit"
SCRIPT_REPO_BRANCH_VALUE="master"

# Set the *rootfs.tar.gz package save name
PACKAGE_FILE="openwrt-armsr-armv8-generic-rootfs.tar.gz"

# Set the list of supported device
PACKAGE_OPENWRT=(
    "ak88" "e52c" "e54c" "h88k" "h88k-v3" "rock5b" "rock5c"
    "cm3" "e25" "photonicat" "r66s" "r68s" "rk3399"
    "e20c" "e24c" "h28k" "h66k" "h68k" "h69k" "h69k-max" "ht2" "jp-tvbox" "watermelon-pi" "yixun-rs6pro" "zcube1-max"
    "s922x" "s922x-n2" "s905x3" "s905x2" "s912" "s905d" "s905"
    "beikeyun" "l1pro"
    "vplus"
    "qemu"
    "diy"
)
# Set the list of devices using the [ rk3588 ] kernel
PACKAGE_OPENWRT_RK3588=("ak88" "e52c" "e54c" "h88k" "h88k-v3" "rock5b" "rock5c")
# Set the list of devices using the [ rk35xx ] kernel
# Devices from the rk3528/rk3399/rk3566/rk3568 series can utilize the rk35xx kernels.
PACKAGE_OPENWRT_RK35XX=("e20c" "e24c" "h28k" "h66k" "h68k" "ht2" "jp-tvbox" "yixun-rs6pro")
# The following devices lack DTB support in the unifreq/linux-6.1.y-rockchip kernel and can only use the rk35xx/5.1.y kernel.
PACKAGE_OPENWRT_RK35XX_5XY=("h69k" "h69k-max" "watermelon-pi" "zcube1-max")
# Set the list of devices using the [ 6.x.y ] kernel
PACKAGE_OPENWRT_6XY=("cm3" "e25" "photonicat" "r66s" "r68s" "rk3399")
# All are packaged by default, and independent settings are supported, such as: [ s905x3_s905d_rock5b ]
PACKAGE_SOC_VALUE="all"

# Set the default packaged kernel download repository
KERNEL_REPO_URL_VALUE="breakingbadboy/OpenWrt"
# Set kernel tag: kernel_stable, kernel_rk3588, kernel_rk35xx
KERNEL_TAGS=("stable" "rk3588" "rk35xx")
STABLE_KERNEL=("6.1.y" "6.12.y")
RK3588_KERNEL=("5.10.y" "6.1.y")
RK35XX_KERNEL=("5.10.y" "6.1.y")
RK35XX_KERNEL_5XY=("5.10.y")
KERNEL_AUTO_LATEST_VALUE="true"

# Set the working directory under /opt
SELECT_PACKITPATH_VALUE="openwrt_packit"
SELECT_OUTPUTPATH_VALUE="output"
GZIP_IMGS_VALUE="auto"
SAVE_OPENWRT_ARMSR_VALUE="true"

# Set the default packaging script
SCRIPT_BEIKEYUN_FILE="mk_rk3328_beikeyun.sh"
SCRIPT_CM3_FILE="mk_rk3566_radxa-cm3-rpi-cm4-io.sh"
SCRIPT_DIY_FILE="mk_diy.sh"
SCRIPT_E20C_FILE="mk_rk3528_e20c.sh"
SCRIPT_E24C_FILE="mk_rk3528_e24c.sh"
SCRIPT_E25_FILE="mk_rk3568_e25.sh"
SCRIPT_E52C_FILE="mk_rk3588s_e52c.sh"
SCRIPT_E54C_FILE="mk_rk3588s_e54c.sh"
SCRIPT_H28K_FILE="mk_rk3528_h28k.sh"
SCRIPT_H66K_FILE="mk_rk3568_h66k.sh"
SCRIPT_H68K_FILE="mk_rk3568_h68k.sh"
SCRIPT_H69K_FILE="mk_rk3568_h69k.sh"
SCRIPT_H88K_FILE="mk_rk3588_h88k.sh"
SCRIPT_H88KV3_FILE="mk_rk3588_h88k-v3.sh"
SCRIPT_HT2_FILE="mk_rk3528_ht2.sh"
SCRIPT_JPTVBOX_FILE="mk_rk3566_jp-tvbox.sh"
SCRIPT_L1PRO_FILE="mk_rk3328_l1pro.sh"
SCRIPT_PHOTONICAT_FILE="mk_rk3568_photonicat.sh"
SCRIPT_QEMU_FILE="mk_qemu-aarch64_img.sh"
SCRIPT_R66S_FILE="mk_rk3568_r66s.sh"
SCRIPT_R68S_FILE="mk_rk3568_r68s.sh"
SCRIPT_RK3399_FILE="mk_rk3399_generic.sh"
SCRIPT_ROCK5B_FILE="mk_rk3588_rock5b.sh"
SCRIPT_ROCK5C_FILE="mk_rk3588s_rock5c.sh"
SCRIPT_S905_FILE="mk_s905_mxqpro+.sh"
SCRIPT_S905D_FILE="mk_s905d_n1.sh"
SCRIPT_S905X2_FILE="mk_s905x2_x96max.sh"
SCRIPT_S905X3_FILE="mk_s905x3_multi.sh"
SCRIPT_S912_FILE="mk_s912_zyxq.sh"
SCRIPT_S922X_FILE="mk_s922x_gtking.sh"
SCRIPT_S922X_N2_FILE="mk_s922x_odroid-n2.sh"
SCRIPT_VPLUS_FILE="mk_h6_vplus.sh"
SCRIPT_WATERMELONPI_FILE="mk_rk3568_watermelon-pi.sh"
SCRIPT_RS6PRO_FILE="mk_rk3528_rs6pro.sh"
SCRIPT_ZCUBE1MAX_FILE="mk_rk3399_zcube1-max.sh"

# Set make.env related parameters
WHOAMI_VALUE="flippy"
OPENWRT_VER_VALUE="auto"
SW_FLOWOFFLOAD_VALUE="1"
HW_FLOWOFFLOAD_VALUE="0"
SFE_FLOW_VALUE="1"
ENABLE_WIFI_K504_VALUE="1"
ENABLE_WIFI_K510_VALUE="1"
DISTRIB_REVISION_VALUE="R$(date +%Y.%m.%d)"
DISTRIB_DESCRIPTION_VALUE="OpenWrt"
OPENWRT_IP_VALUE="192.168.1.1"

# Set font color
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
NOTE="[\033[93m NOTE \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#==============================================================================================

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

init_var() {
    echo -e "${STEPS} Start Initializing Variables..."

    # Install the compressed package
    sudo apt-get -qq update
    sudo apt-get -qq install -y curl git coreutils p7zip p7zip-full zip unzip gzip xz-utils pigz zstd jq tar

    # Specify the default value
    [[ -n "${SCRIPT_REPO_URL}" ]] || SCRIPT_REPO_URL="${SCRIPT_REPO_URL_VALUE}"
    [[ "${SCRIPT_REPO_URL,,}" =~ ^http ]] || SCRIPT_REPO_URL="https://github.com/${SCRIPT_REPO_URL}"
    [[ -n "${SCRIPT_REPO_BRANCH}" ]] || SCRIPT_REPO_BRANCH="${SCRIPT_REPO_BRANCH_VALUE}"
    [[ -n "${KERNEL_REPO_URL}" ]] || KERNEL_REPO_URL="${KERNEL_REPO_URL_VALUE}"
    [[ -n "${PACKAGE_SOC}" ]] || PACKAGE_SOC="${PACKAGE_SOC_VALUE}"
    [[ -n "${KERNEL_AUTO_LATEST}" ]] || KERNEL_AUTO_LATEST="${KERNEL_AUTO_LATEST_VALUE}"
    [[ -n "${GZIP_IMGS}" ]] || GZIP_IMGS="${GZIP_IMGS_VALUE}"
    [[ -n "${SELECT_PACKITPATH}" ]] || SELECT_PACKITPATH="${SELECT_PACKITPATH_VALUE}"
    [[ -n "${SELECT_OUTPUTPATH}" ]] || SELECT_OUTPUTPATH="${SELECT_OUTPUTPATH_VALUE}"
    [[ -n "${SAVE_OPENWRT_ARMSR}" ]] || SAVE_OPENWRT_ARMSR="${SAVE_OPENWRT_ARMSR_VALUE}"

    # Specify the default packaging script
    [[ -n "${SCRIPT_BEIKEYUN}" ]] || SCRIPT_BEIKEYUN="${SCRIPT_BEIKEYUN_FILE}"
    [[ -n "${SCRIPT_CM3}" ]] || SCRIPT_CM3="${SCRIPT_CM3_FILE}"
    [[ -n "${SCRIPT_DIY}" ]] || SCRIPT_DIY="${SCRIPT_DIY_FILE}"
    [[ -n "${SCRIPT_E20C}" ]] || SCRIPT_E20C="${SCRIPT_E20C_FILE}"
    [[ -n "${SCRIPT_E24C}" ]] || SCRIPT_E24C="${SCRIPT_E24C_FILE}"
    [[ -n "${SCRIPT_E25}" ]] || SCRIPT_E25="${SCRIPT_E25_FILE}"
    [[ -n "${SCRIPT_E52C}" ]] || SCRIPT_E52C="${SCRIPT_E52C_FILE}"
    [[ -n "${SCRIPT_E54C}" ]] || SCRIPT_E54C="${SCRIPT_E54C_FILE}"
    [[ -n "${SCRIPT_H28K}" ]] || SCRIPT_H28K="${SCRIPT_H28K_FILE}"
    [[ -n "${SCRIPT_H66K}" ]] || SCRIPT_H66K="${SCRIPT_H66K_FILE}"
    [[ -n "${SCRIPT_H68K}" ]] || SCRIPT_H68K="${SCRIPT_H68K_FILE}"
    [[ -n "${SCRIPT_H69K}" ]] || SCRIPT_H69K="${SCRIPT_H69K_FILE}"
    [[ -n "${SCRIPT_H88K}" ]] || SCRIPT_H88K="${SCRIPT_H88K_FILE}"
    [[ -n "${SCRIPT_H88KV3}" ]] || SCRIPT_H88KV3="${SCRIPT_H88KV3_FILE}"
    [[ -n "${SCRIPT_HT2}" ]] || SCRIPT_HT2="${SCRIPT_HT2_FILE}"
    [[ -n "${SCRIPT_JPTVBOX}" ]] || SCRIPT_JPTVBOX="${SCRIPT_JPTVBOX_FILE}"
    [[ -n "${SCRIPT_L1PRO}" ]] || SCRIPT_L1PRO="${SCRIPT_L1PRO_FILE}"
    [[ -n "${SCRIPT_PHOTONICAT}" ]] || SCRIPT_PHOTONICAT="${SCRIPT_PHOTONICAT_FILE}"
    [[ -n "${SCRIPT_QEMU}" ]] || SCRIPT_QEMU="${SCRIPT_QEMU_FILE}"
    [[ -n "${SCRIPT_R66S}" ]] || SCRIPT_R66S="${SCRIPT_R66S_FILE}"
    [[ -n "${SCRIPT_R68S}" ]] || SCRIPT_R68S="${SCRIPT_R68S_FILE}"
    [[ -n "${SCRIPT_RK3399}" ]] || SCRIPT_RK3399="${SCRIPT_RK3399_FILE}"
    [[ -n "${SCRIPT_ROCK5B}" ]] || SCRIPT_ROCK5B="${SCRIPT_ROCK5B_FILE}"
    [[ -n "${SCRIPT_ROCK5C}" ]] || SCRIPT_ROCK5C="${SCRIPT_ROCK5C_FILE}"
    [[ -n "${SCRIPT_S905}" ]] || SCRIPT_S905="${SCRIPT_S905_FILE}"
    [[ -n "${SCRIPT_S905D}" ]] || SCRIPT_S905D="${SCRIPT_S905D_FILE}"
    [[ -n "${SCRIPT_S905X2}" ]] || SCRIPT_S905X2="${SCRIPT_S905X2_FILE}"
    [[ -n "${SCRIPT_S905X3}" ]] || SCRIPT_S905X3="${SCRIPT_S905X3_FILE}"
    [[ -n "${SCRIPT_S912}" ]] || SCRIPT_S912="${SCRIPT_S912_FILE}"
    [[ -n "${SCRIPT_S922X}" ]] || SCRIPT_S922X="${SCRIPT_S922X_FILE}"
    [[ -n "${SCRIPT_S922X_N2}" ]] || SCRIPT_S922X_N2="${SCRIPT_S922X_N2_FILE}"
    [[ -n "${SCRIPT_VPLUS}" ]] || SCRIPT_VPLUS="${SCRIPT_VPLUS_FILE}"
    [[ -n "${SCRIPT_WATERMELONPI}" ]] || SCRIPT_WATERMELONPI="${SCRIPT_WATERMELONPI_FILE}"
    [[ -n "${SCRIPT_RS6PRO}" ]] || SCRIPT_RS6PRO="${SCRIPT_RS6PRO_FILE}"
    [[ -n "${SCRIPT_ZCUBE1MAX}" ]] || SCRIPT_ZCUBE1MAX="${SCRIPT_ZCUBE1MAX_FILE}"

    # Specify make.env variable
    [[ -n "${WHOAMI}" ]] || WHOAMI="${WHOAMI_VALUE}"
    [[ -n "${OPENWRT_VER}" ]] || OPENWRT_VER="${OPENWRT_VER_VALUE}"
    [[ -n "${SW_FLOWOFFLOAD}" ]] || SW_FLOWOFFLOAD="${SW_FLOWOFFLOAD_VALUE}"
    [[ -n "${HW_FLOWOFFLOAD}" ]] || HW_FLOWOFFLOAD="${HW_FLOWOFFLOAD_VALUE}"
    [[ -n "${SFE_FLOW}" ]] || SFE_FLOW="${SFE_FLOW_VALUE}"
    [[ -n "${ENABLE_WIFI_K504}" ]] || ENABLE_WIFI_K504="${ENABLE_WIFI_K504_VALUE}"
    [[ -n "${ENABLE_WIFI_K510}" ]] || ENABLE_WIFI_K510="${ENABLE_WIFI_K510_VALUE}"
    [[ -n "${DISTRIB_REVISION}" ]] || DISTRIB_REVISION="${DISTRIB_REVISION_VALUE}"
    [[ -n "${DISTRIB_DESCRIPTION}" ]] || DISTRIB_DESCRIPTION="${DISTRIB_DESCRIPTION_VALUE}"
    [[ -n "${OPENWRT_IP}" ]] || OPENWRT_IP="${OPENWRT_IP_VALUE}"

    # Confirm package object
    [[ "${PACKAGE_SOC}" != "all" ]] && {
        oldIFS="${IFS}"
        IFS="_"
        PACKAGE_OPENWRT=(${PACKAGE_SOC})
        IFS="${oldIFS}"
    }

    # Confirm customize rk3399 devices: ${CUSTOMIZE_RK3399}
    # Format:  [ board1:dtb1/board2:dtb2/board3:dtb3/... ]
    #          [ none ]
    # Example: [ tvi3315a:rk3399-tvi3315a.dtb/sw799:rk3399-bozz-sw799.dtb ]
    # If not specified, it can be set to 'none'.
    RK3399_BOARD_LIST=()
    RK3399_DTB_LIST=()
    [[ -n "${CUSTOMIZE_RK3399}" && "${CUSTOMIZE_RK3399,,}" != "none" ]] && {
        # Add rk3399 to the package list
        PACKAGE_OPENWRT+=("rk3399")

        # Split the string
        oldIFS="${IFS}"
        IFS="/"
        for rk in ${CUSTOMIZE_RK3399}; do
            IFS=":"
            tmp_rk_arr=(${rk})
            RK3399_BOARD_LIST+=(${tmp_rk_arr[0]})
            RK3399_DTB_LIST+=(${tmp_rk_arr[1]})
        done
        IFS="${oldIFS}"
    }

    # Remove duplicate package drivers
    PACKAGE_OPENWRT=($(echo "${PACKAGE_OPENWRT[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Reset required kernel tags
    KERNEL_TAGS_TMP=()
    for kt in "${PACKAGE_OPENWRT[@]}"; do
        if [[ " ${PACKAGE_OPENWRT_RK3588[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk3588")
        elif [[ " ${PACKAGE_OPENWRT_RK35XX[@]} " =~ " ${kt} " || " ${PACKAGE_OPENWRT_RK35XX_5XY[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk35xx")
        else
            KERNEL_TAGS_TMP+=("stable")
        fi
    done
    # Remove duplicate kernel tags
    KERNEL_TAGS=($(echo "${KERNEL_TAGS_TMP[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    echo -e "${INFO} Package directory: [ /opt/${SELECT_PACKITPATH} ]"
    echo -e "${INFO} Package SoC: [ $(echo ${PACKAGE_OPENWRT[@]} | xargs) ]"
    echo -e "${INFO} Kernel tags: [ $(echo ${KERNEL_TAGS[@]} | xargs) ]"

    # Reset STABLE_KERNEL options
    [[ -n "${KERNEL_VERSION_NAME}" && " ${KERNEL_TAGS[@]} " =~ " stable " ]] && {
        oldIFS="${IFS}"
        IFS="_"
        STABLE_KERNEL=(${KERNEL_VERSION_NAME})
        IFS="${oldIFS}"
        echo -e "${INFO} Stable kernel: [ $(echo ${STABLE_KERNEL[@]} | xargs) ]"
    }

    # Convert kernel library address to api format
    echo -e "${INFO} Kernel download repository: [ ${KERNEL_REPO_URL} ]"
    [[ "${KERNEL_REPO_URL}" =~ ^https: ]] && KERNEL_REPO_URL="$(echo ${KERNEL_REPO_URL} | awk -F'/' '{print $4"/"$5}')"
    kernel_api="https://github.com/${KERNEL_REPO_URL}"
    echo -e "${INFO} Kernel Query API: [ ${kernel_api} ]"
}

init_packit_repo() {
    cd /opt

    # Clone the repository into the packaging directory. If it fails, wait 1 minute and try again, try 10 times.
    [[ -d "${SELECT_PACKITPATH}" ]] || {
        echo -e "${STEPS} Start cloning repository [ ${SCRIPT_REPO_URL} ], branch [ ${SCRIPT_REPO_BRANCH} ] into [ ${SELECT_PACKITPATH} ]"
        for i in {1..10}; do
            git clone -q --single-branch --depth=1 --branch=${SCRIPT_REPO_BRANCH} ${SCRIPT_REPO_URL} ${SELECT_PACKITPATH}
            [[ "${?}" -eq "0" ]] && break || sleep 60
        done
        [[ -d "${SELECT_PACKITPATH}" ]] || error_msg "Failed to clone the repository."
    }

    # Check the *rootfs.tar.gz package
    # If the original variable name [ OPENWRT_ARMVIRT ] is detected, it will be inherited and used.
    [[ -n "${OPENWRT_ARMVIRT}" && -z "${OPENWRT_ARMSR}" ]] && OPENWRT_ARMSR="${OPENWRT_ARMVIRT}"
    [[ -z "${OPENWRT_ARMSR}" ]] && error_msg "The [ OPENWRT_ARMSR ] variable must be specified."

    # Load *-armsr-armv8-generic-rootfs.tar.gz
    rm -f ${SELECT_PACKITPATH}/${PACKAGE_FILE}
    if [[ "${OPENWRT_ARMSR,,}" =~ ^http ]]; then
        echo -e "${STEPS} Download the [ ${OPENWRT_ARMSR} ] file into [ ${SELECT_PACKITPATH} ]"

        # Download the *-armsr-armv8-generic-rootfs.tar.gz file. If the download fails, try again 10 times.
        for i in {1..10}; do
            curl -fsSL "${OPENWRT_ARMSR}" -o "${SELECT_PACKITPATH}/${PACKAGE_FILE}"
            [[ "${?}" -eq "0" ]] && break || sleep 60
        done
        [[ "${?}" -eq "0" ]] || error_msg "Openwrt rootfs file download failed."
    else
        echo -e "${STEPS} copy [ ${GITHUB_WORKSPACE}/${OPENWRT_ARMSR} ] file into [ ${SELECT_PACKITPATH} ]"
        cp -f ${GITHUB_WORKSPACE}/${OPENWRT_ARMSR} ${SELECT_PACKITPATH}/${PACKAGE_FILE}
        [[ "${?}" -eq "0" ]] || error_msg "Openwrt rootfs file copy failed."
    fi

    # Normal ${PACKAGE_FILE} file should not be less than 10MB
    armvirt_rootfs_size="$(ls -l ${SELECT_PACKITPATH}/${PACKAGE_FILE} 2>/dev/null | awk '{print $5}')"
    echo -e "${INFO} armvirt_rootfs_size: [ ${armvirt_rootfs_size} ]"
    if [[ "${armvirt_rootfs_size}" -ge "10000000" ]]; then
        echo -e "${INFO} [ ${SELECT_PACKITPATH}/${PACKAGE_FILE} ] loaded successfully."
    else
        error_msg "The [ ${SELECT_PACKITPATH}/${PACKAGE_FILE} ] failed to load."
    fi

    # Modify default IP address
    echo -e "${STEPS} Start modifying the OpenWrt default IP address to [ ${OPENWRT_IP} ]"
    tmpdir="$(mktemp -d)"
    tar -xzpf "${SELECT_PACKITPATH}/${PACKAGE_FILE}" -C "${tmpdir}"
    sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${OPENWRT_IP}\"}/" "${tmpdir}/bin/config_generate"
    tar -czpf "${SELECT_PACKITPATH}/${PACKAGE_FILE}" -C "${tmpdir}" .
    rm -rf "${tmpdir}"

    # Add custom script
    [[ -n "${SCRIPT_DIY_PATH}" ]] && {
        rm -f ${SELECT_PACKITPATH}/${SCRIPT_DIY}
        if [[ "${SCRIPT_DIY_PATH,,}" =~ ^http ]]; then
            echo -e "${INFO} Download the custom script file: [ ${SCRIPT_DIY_PATH} ]"

            # Download the custom script file. If the download fails, try again 10 times.
            for i in {1..10}; do
                curl -fsSL "${SCRIPT_DIY_PATH}" -o "${SELECT_PACKITPATH}/${SCRIPT_DIY}"
                [[ "${?}" -eq "0" ]] && break || sleep 60
            done
            [[ "${?}" -eq "0" ]] || error_msg "Custom script file download failed."
        else
            echo -e "${INFO} Copy custom script file: [ ${SCRIPT_DIY_PATH} ]"
            cp -f ${GITHUB_WORKSPACE}/${SCRIPT_DIY_PATH} ${SELECT_PACKITPATH}/${SCRIPT_DIY}
            [[ "${?}" -eq "0" ]] || error_msg "Custom script file copy failed."
        fi
        chmod +x ${SELECT_PACKITPATH}/${SCRIPT_DIY}
        echo -e "List of [ ${SELECT_PACKITPATH} ] directory files:\n $(ls -lh ${SELECT_PACKITPATH})"
    }
}

query_kernel() {
    echo -e "${STEPS} Start querying the latest kernel..."

    # Check the version on the kernel library
    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Select the corresponding kernel directory and list
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Query the name of the latest kernel version
            TMP_ARR_KERNELS=()
            i=1
            for kernel_var in "${down_kernel_list[@]}"; do
                echo -e "${INFO} (${i}) Auto query the latest kernel version of the same series for [ ${vb} - ${kernel_var} ]"

                # Identify the kernel <VERSION> and <PATCHLEVEL>, such as [ 6.1 ]
                kernel_verpatch="$(echo ${kernel_var} | awk -F '.' '{print $1"."$2}')"

                # Query the latest kernel version
                latest_version="$(
                    curl -fsSL \
                        ${kernel_api}/releases/expanded_assets/kernel_${vb} |
                        grep -oE "${kernel_verpatch}\.[0-9]+.*\.tar\.gz" | sed 's/.tar.gz//' |
                        sort -urV | head -n 1
                )"

                if [[ "$?" -eq "0" && -n "${latest_version}" ]]; then
                    TMP_ARR_KERNELS[${i}]="${latest_version}"
                else
                    TMP_ARR_KERNELS[${i}]="${kernel_var}"
                fi

                echo -e "${INFO} (${i}) [ ${vb} - ${TMP_ARR_KERNELS[$i]} ] is latest kernel."

                let i++
            done

            # Reset the kernel array to the latest kernel version
            if [[ "${vb,,}" == "rk3588" ]]; then
                RK3588_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the rk3588 kernel: [ ${RK3588_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                RK35XX_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the rk35xx kernel: [ ${RK35XX_KERNEL[@]} ]"
            else
                STABLE_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} The latest version of the stable kernel: [ ${STABLE_KERNEL[@]} ]"
            fi

            let x++
        }
    done
}

check_kernel() {
    [[ -n "${1}" ]] && check_path="${1}" || error_msg "Invalid kernel path to check."
    check_files=($(cat "${check_path}/sha256sums" | awk '{print $2}'))
    m="1"
    for cf in "${check_files[@]}"; do
        {
            # Check if file exists
            [[ -s "${check_path}/${cf}" ]] || error_msg "The [ ${cf} ] file is missing."
            # Check if the file sha256sum is correct
            tmp_sha256sum="$(sha256sum "${check_path}/${cf}" | awk '{print $1}')"
            tmp_checkcode="$(cat ${check_path}/sha256sums | grep ${cf} | awk '{print $1}')"
            [[ "${tmp_sha256sum,,}" == "${tmp_checkcode,,}" ]] || error_msg "[ ${cf} ]: sha256sum verification failed."
            let m++
        }
    done
    echo -e "${INFO} All [ ${#check_files[@]} ] kernel files are sha256sum checked to be complete.\n"
}

download_kernel() {
    echo -e "${STEPS} Start downloading the kernel..."

    cd /opt

    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Set the kernel download list
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Kernel storage directory
            kernel_path="kernel/${vb}"
            [[ -d "${kernel_path}" ]] || mkdir -p ${kernel_path}

            # Download the kernel to the storage directory
            i="1"
            for kernel_var in "${down_kernel_list[@]}"; do
                if [[ ! -d "${kernel_path}/${kernel_var}" ]]; then
                    kernel_down_from="https://github.com/${KERNEL_REPO_URL}/releases/download/kernel_${vb}/${kernel_var}.tar.gz"
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Kernel download from [ ${kernel_down_from} ]"

                    # Download the kernel file. If the download fails, try again 10 times.
                    for t in {1..10}; do
                        curl -fsSL "${kernel_down_from}" -o "${kernel_path}/${kernel_var}.tar.gz"
                        [[ "${?}" -eq "0" ]] && break || sleep 60
                    done
                    [[ "${?}" -eq "0" ]] || error_msg "Failed to download the kernel files from the server."

                    # Decompress the kernel file
                    tar -mxf "${kernel_path}/${kernel_var}.tar.gz" -C "${kernel_path}"
                    [[ "${?}" -eq "0" ]] || error_msg "[ ${kernel_var} ] kernel decompression failed."
                else
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Kernel is in the local directory."
                fi

                # If the kernel contains the sha256sums file, check the files integrity
                [[ -f "${kernel_path}/${kernel_var}/sha256sums" ]] && check_kernel "${kernel_path}/${kernel_var}"

                let i++
            done

            # Delete downloaded kernel temporary files
            rm -f ${kernel_path}/*.tar.gz
            sync

            let x++
        }
    done
}

make_openwrt() {
    echo -e "${STEPS} Start packaging OpenWrt..."

    i="1"
    for PACKAGE_VAR in "${PACKAGE_OPENWRT[@]}"; do
        {
            # Distinguish between different OpenWrt and use different kernel
            if [[ " ${PACKAGE_OPENWRT_RK3588[@]} " =~ " ${PACKAGE_VAR} " ]]; then
                build_kernel=(${RK3588_KERNEL[@]})
                vb="rk3588"
            elif [[ " ${PACKAGE_OPENWRT_RK35XX[@]} " =~ " ${PACKAGE_VAR} " ]]; then
                build_kernel=(${RK35XX_KERNEL[@]})
                vb="rk35xx"
            elif [[ " ${PACKAGE_OPENWRT_RK35XX_5XY[@]} " =~ " ${PACKAGE_VAR} " ]]; then
                build_kernel=($(printf "%s\n" "${RK35XX_KERNEL[@]}" | grep -E "^$(IFS='|'; echo "${RK35XX_KERNEL_5XY[@]//.y/\\.}" | sed 's/ /|/g')"))
                vb="rk35xx"
            else
                build_kernel=(${STABLE_KERNEL[@]})
                vb="stable"
            fi

            k="1"
            for kernel_var in "${build_kernel[@]}"; do
                {
                    # Rockchip rk3568 series only support 6.x.y and above kernel
                    [[ -n "$(echo "${PACKAGE_OPENWRT_6XY[@]}" | grep -w "${PACKAGE_VAR}")" && "${kernel_var:0:2}" != "6." ]] && {
                        echo -e "${STEPS} (${i}.${k}) ${NOTE} Based on <PACKAGE_OPENWRT_6XY>, skip the [ ${PACKAGE_VAR} - ${vb}/${kernel_var} ] build."
                        let k++
                        continue
                    }

                    # Check the available size of server space
                    now_remaining_space="$(df -Tk /opt/${SELECT_PACKITPATH} | tail -n1 | awk '{print $5}' | echo $(($(xargs) / 1024 / 1024)))"
                    [[ "${now_remaining_space}" -le "3" ]] && {
                        echo -e "${WARNING} If the remaining space is less than 3G, exit this packaging. \n"
                        break
                    }

                    cd /opt/kernel

                    # Copy the kernel to the packaging directory
                    rm -f *.tar.gz
                    cp -f ${vb}/${kernel_var}/* .
                    #
                    boot_kernel_file="$(ls boot-${kernel_var}* 2>/dev/null | head -n 1)"
                    KERNEL_VERSION="${boot_kernel_file:5:-7}"
                    [[ "${vb,,}" == "rk3588" ]] && RK3588_KERNEL_VERSION="${KERNEL_VERSION}" || RK3588_KERNEL_VERSION=""
                    [[ "${vb,,}" == "rk35xx" ]] && RK35XX_KERNEL_VERSION="${KERNEL_VERSION}" || RK35XX_KERNEL_VERSION=""
                    echo -e "${STEPS} (${i}.${k}) Start packaging OpenWrt: [ ${PACKAGE_VAR} ], Kernel directory: [ ${vb} ], Kernel version: [ ${KERNEL_VERSION} ]"
                    echo -e "${INFO} Remaining space is ${now_remaining_space}G. \n"

                    cd /opt/${SELECT_PACKITPATH}

                    # If flowoffload is turned on, then sfe is forced to be closed by default
                    [[ "${SW_FLOWOFFLOAD}" -eq "1" ]] && SFE_FLOW="0"

                    if [[ -n "${OPENWRT_VER}" && "${OPENWRT_VER,,}" == "auto" ]]; then
                        OPENWRT_VER="$(cat make.env | grep "OPENWRT_VER=\"" | cut -d '"' -f2)"
                        echo -e "${INFO} (${i}.${k}) OPENWRT_VER: [ ${OPENWRT_VER} ]"
                    fi

                    # Generate a custom make.env file
                    rm -f make.env 2>/dev/null
                    cat >make.env <<EOF
WHOAMI="${WHOAMI}"
OPENWRT_VER="${OPENWRT_VER}"
RK3588_KERNEL_VERSION="${RK3588_KERNEL_VERSION}"
RK35XX_KERNEL_VERSION="${RK35XX_KERNEL_VERSION}"
KERNEL_VERSION="${KERNEL_VERSION}"
KERNEL_PKG_HOME="/opt/kernel"
SW_FLOWOFFLOAD="${SW_FLOWOFFLOAD}"
HW_FLOWOFFLOAD="${HW_FLOWOFFLOAD}"
SFE_FLOW="${SFE_FLOW}"
ENABLE_WIFI_K504="${ENABLE_WIFI_K504}"
ENABLE_WIFI_K510="${ENABLE_WIFI_K510}"
DISTRIB_REVISION="${DISTRIB_REVISION}"
DISTRIB_DESCRIPTION="${DISTRIB_DESCRIPTION}"
EOF

                    #echo -e "${INFO} make.env file info:"
                    #cat make.env

                    # Select the corresponding packaging script
                    case "${PACKAGE_VAR}" in
                        ak88)             [[ -f "${SCRIPT_H88K}" ]]            && sudo ./${SCRIPT_H88K} ;;
                        beikeyun)         [[ -f "${SCRIPT_BEIKEYUN}" ]]        && sudo ./${SCRIPT_BEIKEYUN} ;;
                        cm3)              [[ -f "${SCRIPT_CM3}" ]]             && sudo ./${SCRIPT_CM3} ;;
                        diy)              [[ -f "${SCRIPT_DIY}" ]]             && sudo ./${SCRIPT_DIY} ;;
                        e20c)             [[ -f "${SCRIPT_E20C}" ]]            && sudo ./${SCRIPT_E20C} ;;
                        e24c)             [[ -f "${SCRIPT_E24C}" ]]            && sudo ./${SCRIPT_E24C} ;;
                        e25)              [[ -f "${SCRIPT_E25}" ]]             && sudo ./${SCRIPT_E25} ;;
                        e52c)             [[ -f "${SCRIPT_E52C}" ]]            && sudo ./${SCRIPT_E52C} ;;
                        e54c)             [[ -f "${SCRIPT_E54C}" ]]            && sudo ./${SCRIPT_E54C} ;;
                        h28k)             [[ -f "${SCRIPT_H28K}" ]]            && sudo ./${SCRIPT_H28K} ;;
                        h66k)             [[ -f "${SCRIPT_H66K}" ]]            && sudo ./${SCRIPT_H66K} ;;
                        h68k)             [[ -f "${SCRIPT_H68K}" ]]            && sudo ./${SCRIPT_H68K} ;;
                        h69k)             [[ -f "${SCRIPT_H69K}" ]]            && sudo ./${SCRIPT_H69K} ;;
                        h69k-max)         [[ -f "${SCRIPT_H69K}" ]]            && sudo ./${SCRIPT_H69K} "max" ;;
                        h88k)             [[ -f "${SCRIPT_H88K}" ]]            && sudo ./${SCRIPT_H88K} "25" ;;
                        h88k-v3)          [[ -f "${SCRIPT_H88KV3}" ]]          && sudo ./${SCRIPT_H88KV3} ;;
                        ht2)              [[ -f "${SCRIPT_HT2}" ]]             && sudo ./${SCRIPT_HT2} ;;
                        jp-tvbox)         [[ -f "${SCRIPT_JPTVBOX}" ]]         && sudo ./${SCRIPT_JPTVBOX} ;;
                        l1pro)            [[ -f "${SCRIPT_L1PRO}" ]]           && sudo ./${SCRIPT_L1PRO} ;;
                        photonicat)       [[ -f "${SCRIPT_PHOTONICAT}" ]]      && sudo ./${SCRIPT_PHOTONICAT} ;;
                        qemu)             [[ -f "${SCRIPT_QEMU}" ]]            && sudo ./${SCRIPT_QEMU} ;;
                        r66s)             [[ -f "${SCRIPT_R66S}" ]]            && sudo ./${SCRIPT_R66S} ;;
                        r68s)             [[ -f "${SCRIPT_R68S}" ]]            && sudo ./${SCRIPT_R68S} ;;
                        rock5b)           [[ -f "${SCRIPT_ROCK5B}" ]]          && sudo ./${SCRIPT_ROCK5B} ;;
                        rock5c)           [[ -f "${SCRIPT_ROCK5C}" ]]          && sudo ./${SCRIPT_ROCK5C} ;;
                        s905)             [[ -f "${SCRIPT_S905}" ]]            && sudo ./${SCRIPT_S905} ;;
                        s905d)            [[ -f "${SCRIPT_S905D}" ]]           && sudo ./${SCRIPT_S905D} ;;
                        s905x2)           [[ -f "${SCRIPT_S905X2}" ]]          && sudo ./${SCRIPT_S905X2} ;;
                        s905x3)           [[ -f "${SCRIPT_S905X3}" ]]          && sudo ./${SCRIPT_S905X3} ;;
                        s912)             [[ -f "${SCRIPT_S912}" ]]            && sudo ./${SCRIPT_S912} ;;
                        s922x)            [[ -f "${SCRIPT_S922X}" ]]           && sudo ./${SCRIPT_S922X} ;;
                        s922x-n2)         [[ -f "${SCRIPT_S922X_N2}" ]]        && sudo ./${SCRIPT_S922X_N2} ;;
                        vplus)            [[ -f "${SCRIPT_VPLUS}" ]]           && sudo ./${SCRIPT_VPLUS} ;;
                        watermelon-pi)    [[ -f "${SCRIPT_WATERMELONPI}" ]]    && sudo ./${SCRIPT_WATERMELONPI} ;;
                        yixun-rs6pro)     [[ -f "${SCRIPT_RS6PRO}" ]]          && sudo ./${SCRIPT_RS6PRO} ;;
                        zcube1-max)       [[ -f "${SCRIPT_ZCUBE1MAX}" ]]       && sudo ./${SCRIPT_ZCUBE1MAX} ;;
                        rk3399)           [[ -f "${SCRIPT_RK3399}" && ${#RK3399_BOARD_LIST[@]} -gt 0 ]] && {
                                          for rbl in ${!RK3399_BOARD_LIST[@]}; do
                                              sudo ./${SCRIPT_RK3399} ${RK3399_BOARD_LIST[rbl]} ${RK3399_DTB_LIST[rbl]}
                                          done
                                          } ;;
                        *)                echo -e "${WARNING} Have no this SoC. Skipped." && continue ;;
                    esac

                    # Generate compressed file
                    img_num="$(ls /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}/*.img 2>/dev/null | wc -l)"
                    [[ "${img_num}" -ne "0" ]] && {
                        echo -e "${STEPS} (${i}.${k}) Start making compressed files in the [ ${SELECT_OUTPUTPATH} ] directory."
                        cd /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}
                        case "${GZIP_IMGS}" in
                            7z | .7z)      ls *.img | head -n 1 | xargs -I % sh -c 'sudo 7z a -t7z -r %.7z %; rm -f %' ;;
                            xz | .xz)      sudo xz -z *.img ;;
                            zip | .zip)    ls *.img | head -n 1 | xargs -I % sh -c 'sudo zip %.zip %; rm -f %' ;;
                            zst | .zst)    sudo zstd --rm *.img ;;
                            gz | .gz | *)  sudo pigz -f *.img ;;
                        esac
                    }

                    echo -e "${SUCCESS} (${i}.${k}) OpenWrt packaging succeeded: [ ${PACKAGE_VAR} - ${vb} - ${kernel_var} ] \n"
                    sync

                    let k++
                }
            done

            let i++
        }
    done

    echo -e "${SUCCESS} All packaged completed. \n"
}

out_github_env() {
    echo -e "${STEPS} Output github.com environment variables..."
    if [[ -d "/opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}" ]]; then

        cd /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}

        if [[ "${SAVE_OPENWRT_ARMSR,,}" == "true" ]]; then
            echo -e "${INFO} copy [ ${PACKAGE_FILE} ] into [ ${SELECT_OUTPUTPATH} ]"
            sudo cp -f ../${PACKAGE_FILE} . || true
        fi

        # Generate a sha256sum verification file for each OpenWrt file
        #for file in *; do [[ -f "${file}" ]] && sudo sha256sum "${file}" | sudo tee "${file}.sha" >/dev/null; done
        #sudo rm -f *.sha.sha 2>/dev/null

        echo "PACKAGED_OUTPUTPATH=${PWD}" >>${GITHUB_ENV}
        echo "PACKAGED_OUTPUTDATE=$(date +"%m.%d.%H%M")" >>${GITHUB_ENV}
        echo "PACKAGED_STATUS=success" >>${GITHUB_ENV}
        echo -e "PACKAGED_OUTPUTPATH: ${PWD}"
        echo -e "PACKAGED_OUTPUTDATE: $(date +"%m.%d.%H%M")"
        echo -e "PACKAGED_STATUS: success"
        echo -e "${INFO} PACKAGED_OUTPUTPATH files list:"
        echo -e "$(ls -lh /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH} 2>/dev/null) \n"
    else
        echo -e "${ERROR} Packaging failed. \n"
        echo "PACKAGED_STATUS=failure" >>${GITHUB_ENV}
    fi
}
# Show welcome message
echo -e "${STEPS} Welcome to use the OpenWrt packaging tool! \n"
echo -e "${INFO} Server CPU configuration information: \n$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c) \n"

# Start initializing variables
init_var
init_packit_repo

# Show server start information
echo -e "${INFO} Server space usage before starting to compile:\n$(df -hT /opt/${SELECT_PACKITPATH}) \n"

# Packit OpenWrt
[[ "${KERNEL_AUTO_LATEST,,}" == "true" ]] && query_kernel
download_kernel
make_openwrt
out_github_env

# Show server end information
echo -e "${INFO} Server space usage after compilation:\n$(df -hT /opt/${SELECT_PACKITPATH}) \n"
echo -e "${SUCCESS} The packaging process has been completed. \n"
