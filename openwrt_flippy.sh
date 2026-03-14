#!/usr/bin/env bash
#==============================================================================================
#
# Description: Automated OpenWrt Firmware Packaging Tool
# Function: Package OpenWrt firmware using Flippy's kernel files and scripts
# Copyright (C) 2021 https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021 https://github.com/ophub/flippy-openwrt-actions
#
#======================================= Functions list =======================================
#
# error_msg         : Print error message and exit
# download_retry    : Download file with retry mechanism
# init_var          : Initialize environment variables and configuration
# init_packit_repo  : Initialize packaging repository and load rootfs
# query_kernel      : Query the latest kernel versions from repository
# check_kernel      : Verify kernel file integrity via SHA256 checksums
# download_kernel   : Download and extract kernel files from repository
# make_openwrt      : Package OpenWrt firmware for all target devices
# out_github_env    : Export packaging results to GitHub Actions environment
#
#=============================== Set make environment variables ===============================
#
# Default packaging script source repository
SCRIPT_REPO_URL_VALUE="https://github.com/unifreq/openwrt_packit"
SCRIPT_REPO_BRANCH_VALUE="master"
# Filename for the rootfs.tar.gz package
PACKAGE_FILE="openwrt-armsr-armv8-generic-rootfs.tar.gz"
# Working directories under /opt
SELECT_PACKITPATH_VALUE="openwrt_packit"
SELECT_OUTPUTPATH_VALUE="output"
GZIP_IMGS_VALUE="auto"
SAVE_OPENWRT_ROOTFS_VALUE="true"

# List of all supported devices
PACKAGE_OPENWRT=(
    "ak88" "e52c" "e54c" "h88k" "h88k-v3" "rock5b" "rock5c"
    "100ask-dshanpi-a1" "e20c" "e24c" "h28k" "h66k" "h68k" "h69k" "h69k-max" "ht2"
    "jp-tvbox" "watermelon-pi" "yixun-rs6pro" "zcube1-max"
    "cm3" "e25" "photonicat" "r66s" "r68s" "rk3399"
    "s922x" "s922x-n2" "s905x3" "s905x2" "s912" "s905d" "s905"
    "beikeyun" "l1pro"
    "vplus"
    "qemu"
    "diy"
)
# Devices using the [ rk3588 ] kernel
PACKAGE_OPENWRT_RK3588=("ak88" "e52c" "e54c" "h88k" "h88k-v3" "rock5b" "rock5c")
# Devices using the [ rk35xx ] kernel
PACKAGE_OPENWRT_RK35XX=(
    "100ask-dshanpi-a1" "e20c" "e24c" "h28k" "h66k" "h68k" "h69k" "h69k-max" "ht2"
    "jp-tvbox" "watermelon-pi" "yixun-rs6pro" "zcube1-max"
)
# Devices using the [ 6.x.y ] kernel
PACKAGE_OPENWRT_6XY=("cm3" "e25" "photonicat" "r66s" "r68s" "rk3399")
# Package all devices by default; specify individual devices like: [ s905x3_s905d_rock5b ]
PACKAGE_SOC_VALUE="all"

# Default kernel download repository: https://github.com/breakingbadboy/OpenWrt/releases
KERNEL_REPO_URL_VALUE="breakingbadboy/OpenWrt"
# Kernel tags and version configuration: kernel_stable, kernel_rk3588, kernel_rk35xx
KERNEL_TAGS=("stable" "rk3588" "rk35xx")
STABLE_KERNEL=("6.12.y" "6.18.y")
RK3588_KERNEL=("6.1.y")
RK35XX_KERNEL=("6.1.y")
# Flippy kernel from ophub/kernel repository: https://github.com/ophub/kernel/releases
FLIPPY_KERNEL=(${STABLE_KERNEL[@]})
# Automatically query the latest kernel version
KERNEL_AUTO_LATEST_VALUE="true"

# Default OpenWrt LAN IP address
OPENWRT_IP_DEFAULT_VALUE="192.168.1.1"
IP_REGEX="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"

# Device-specific packaging scripts
SCRIPT_100ASKDSHANPIA1_FILE="mk_rk3576_100ask-dshanpi-a1.sh"
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

# Default make.env parameters
WHOAMI_VALUE="flippy"
OPENWRT_VER_VALUE="auto"
SW_FLOWOFFLOAD_VALUE="1"
HW_FLOWOFFLOAD_VALUE="0"
SFE_FLOW_VALUE="1"
ENABLE_WIFI_K504_VALUE="1"
ENABLE_WIFI_K510_VALUE="1"
DISTRIB_REVISION_VALUE="R$(date +%Y.%m.%d)"
DISTRIB_DESCRIPTION_VALUE="OpenWrt"

# Output formatting color tags
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

download_retry() {
    local url="${1}"
    local dest="${2}"
    for i in {1..10}; do
        curl -fsSL "${url}" -o "${dest}" && return 0
        sleep 20
    done
    return 1
}

init_var() {
    echo -e "${STEPS} Initializing environment variables..."

    # Install required dependencies
    sudo apt-get -qq update
    sudo apt-get -qq install -y curl git coreutils p7zip p7zip-full zip unzip gzip xz-utils pigz zstd jq tar

    # Load user-defined repository parameters
    SCRIPT_REPO_URL="${SCRIPT_REPO_URL:-${SCRIPT_REPO_URL_VALUE}}"
    [[ "${SCRIPT_REPO_URL,,}" =~ ^http ]] || SCRIPT_REPO_URL="https://github.com/${SCRIPT_REPO_URL}"
    SCRIPT_REPO_BRANCH="${SCRIPT_REPO_BRANCH:-${SCRIPT_REPO_BRANCH_VALUE}}"
    SELECT_PACKITPATH="${SELECT_PACKITPATH:-${SELECT_PACKITPATH_VALUE}}"
    SELECT_OUTPUTPATH="${SELECT_OUTPUTPATH:-${SELECT_OUTPUTPATH_VALUE}}"
    GZIP_IMGS="${GZIP_IMGS:-${GZIP_IMGS_VALUE}}"
    SAVE_OPENWRT_ROOTFS="${SAVE_OPENWRT_ROOTFS:-${SAVE_OPENWRT_ROOTFS_VALUE}}"

    # Load user-defined SoC and kernel parameters
    PACKAGE_SOC="${PACKAGE_SOC:-${PACKAGE_SOC_VALUE}}"
    KERNEL_REPO_URL="${KERNEL_REPO_URL:-${KERNEL_REPO_URL_VALUE}}"
    KERNEL_AUTO_LATEST="${KERNEL_AUTO_LATEST:-${KERNEL_AUTO_LATEST_VALUE}}"

    # Load user-defined packaging script parameters
    SCRIPT_100ASKDSHANPIA1="${SCRIPT_100ASKDSHANPIA1:-${SCRIPT_100ASKDSHANPIA1_FILE}}"
    SCRIPT_BEIKEYUN="${SCRIPT_BEIKEYUN:-${SCRIPT_BEIKEYUN_FILE}}"
    SCRIPT_CM3="${SCRIPT_CM3:-${SCRIPT_CM3_FILE}}"
    SCRIPT_DIY="${SCRIPT_DIY:-${SCRIPT_DIY_FILE}}"
    SCRIPT_E20C="${SCRIPT_E20C:-${SCRIPT_E20C_FILE}}"
    SCRIPT_E24C="${SCRIPT_E24C:-${SCRIPT_E24C_FILE}}"
    SCRIPT_E25="${SCRIPT_E25:-${SCRIPT_E25_FILE}}"
    SCRIPT_E52C="${SCRIPT_E52C:-${SCRIPT_E52C_FILE}}"
    SCRIPT_E54C="${SCRIPT_E54C:-${SCRIPT_E54C_FILE}}"
    SCRIPT_H28K="${SCRIPT_H28K:-${SCRIPT_H28K_FILE}}"
    SCRIPT_H66K="${SCRIPT_H66K:-${SCRIPT_H66K_FILE}}"
    SCRIPT_H68K="${SCRIPT_H68K:-${SCRIPT_H68K_FILE}}"
    SCRIPT_H69K="${SCRIPT_H69K:-${SCRIPT_H69K_FILE}}"
    SCRIPT_H88K="${SCRIPT_H88K:-${SCRIPT_H88K_FILE}}"
    SCRIPT_H88KV3="${SCRIPT_H88KV3:-${SCRIPT_H88KV3_FILE}}"
    SCRIPT_HT2="${SCRIPT_HT2:-${SCRIPT_HT2_FILE}}"
    SCRIPT_JPTVBOX="${SCRIPT_JPTVBOX:-${SCRIPT_JPTVBOX_FILE}}"
    SCRIPT_L1PRO="${SCRIPT_L1PRO:-${SCRIPT_L1PRO_FILE}}"
    SCRIPT_PHOTONICAT="${SCRIPT_PHOTONICAT:-${SCRIPT_PHOTONICAT_FILE}}"
    SCRIPT_QEMU="${SCRIPT_QEMU:-${SCRIPT_QEMU_FILE}}"
    SCRIPT_R66S="${SCRIPT_R66S:-${SCRIPT_R66S_FILE}}"
    SCRIPT_R68S="${SCRIPT_R68S:-${SCRIPT_R68S_FILE}}"
    SCRIPT_RK3399="${SCRIPT_RK3399:-${SCRIPT_RK3399_FILE}}"
    SCRIPT_ROCK5B="${SCRIPT_ROCK5B:-${SCRIPT_ROCK5B_FILE}}"
    SCRIPT_ROCK5C="${SCRIPT_ROCK5C:-${SCRIPT_ROCK5C_FILE}}"
    SCRIPT_S905="${SCRIPT_S905:-${SCRIPT_S905_FILE}}"
    SCRIPT_S905D="${SCRIPT_S905D:-${SCRIPT_S905D_FILE}}"
    SCRIPT_S905X2="${SCRIPT_S905X2:-${SCRIPT_S905X2_FILE}}"
    SCRIPT_S905X3="${SCRIPT_S905X3:-${SCRIPT_S905X3_FILE}}"
    SCRIPT_S912="${SCRIPT_S912:-${SCRIPT_S912_FILE}}"
    SCRIPT_S922X="${SCRIPT_S922X:-${SCRIPT_S922X_FILE}}"
    SCRIPT_S922X_N2="${SCRIPT_S922X_N2:-${SCRIPT_S922X_N2_FILE}}"
    SCRIPT_VPLUS="${SCRIPT_VPLUS:-${SCRIPT_VPLUS_FILE}}"
    SCRIPT_WATERMELONPI="${SCRIPT_WATERMELONPI:-${SCRIPT_WATERMELONPI_FILE}}"
    SCRIPT_RS6PRO="${SCRIPT_RS6PRO:-${SCRIPT_RS6PRO_FILE}}"
    SCRIPT_ZCUBE1MAX="${SCRIPT_ZCUBE1MAX:-${SCRIPT_ZCUBE1MAX_FILE}}"

    # Load user-defined make.env parameters
    WHOAMI="${WHOAMI:-${WHOAMI_VALUE}}"
    OPENWRT_VER="${OPENWRT_VER:-${OPENWRT_VER_VALUE}}"
    SW_FLOWOFFLOAD="${SW_FLOWOFFLOAD:-${SW_FLOWOFFLOAD_VALUE}}"
    HW_FLOWOFFLOAD="${HW_FLOWOFFLOAD:-${HW_FLOWOFFLOAD_VALUE}}"
    SFE_FLOW="${SFE_FLOW:-${SFE_FLOW_VALUE}}"
    ENABLE_WIFI_K504="${ENABLE_WIFI_K504:-${ENABLE_WIFI_K504_VALUE}}"
    ENABLE_WIFI_K510="${ENABLE_WIFI_K510:-${ENABLE_WIFI_K510_VALUE}}"
    DISTRIB_REVISION="${DISTRIB_REVISION:-${DISTRIB_REVISION_VALUE}}"
    DISTRIB_DESCRIPTION="${DISTRIB_DESCRIPTION:-${DISTRIB_DESCRIPTION_VALUE}}"
    OPENWRT_IP="${OPENWRT_IP:-${OPENWRT_IP_DEFAULT_VALUE}}"
    [[ ! "${OPENWRT_IP}" =~ ${IP_REGEX} ]] && OPENWRT_IP="${OPENWRT_IP_DEFAULT_VALUE}"

    # Resolve target devices from PACKAGE_SOC
    [[ "${PACKAGE_SOC}" != "all" ]] && {
        oldIFS="${IFS}"
        IFS="_"
        PACKAGE_OPENWRT=(${PACKAGE_SOC})
        IFS="${oldIFS}"
    }

    # Parse custom rk3399 device configuration: ${CUSTOMIZE_RK3399}
    # Format:  [ board1:dtb1/board2:dtb2/board3:dtb3/... ]
    #          [ none ]
    # Example: [ tvi3315a:rk3399-tvi3315a.dtb/sw799:rk3399-bozz-sw799.dtb ]
    # If not specified, it can be set to 'none'.
    RK3399_BOARD_LIST=()
    RK3399_DTB_LIST=()
    [[ -n "${CUSTOMIZE_RK3399}" && "${CUSTOMIZE_RK3399,,}" != "none" ]] && {
        # Add rk3399 to the target device list
        PACKAGE_OPENWRT+=("rk3399")

        # Parse board:dtb pairs
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

    # Deduplicate target device list
    PACKAGE_OPENWRT=($(echo "${PACKAGE_OPENWRT[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Convert kernel repository URL to API format
    echo -e "${INFO} Kernel repository: [ ${KERNEL_REPO_URL} ]"
    [[ "${KERNEL_REPO_URL}" =~ ^https: ]] && KERNEL_REPO_URL="$(echo ${KERNEL_REPO_URL} | awk -F'/' '{print $4"/"$5}')"
    kernel_api="https://github.com/${KERNEL_REPO_URL}"

    # Determine required kernel tags based on target devices
    KERNEL_TAGS_TMP=()
    for kt in "${PACKAGE_OPENWRT[@]}"; do
        if [[ " ${PACKAGE_OPENWRT_RK3588[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk3588")
        elif [[ " ${PACKAGE_OPENWRT_RK35XX[@]} " =~ " ${kt} " ]]; then
            KERNEL_TAGS_TMP+=("rk35xx")
        else
            # Use stable kernel by default; use flippy kernel when using the ophub repository
            if [[ "${KERNEL_REPO_URL}" == "ophub/kernel" ]]; then
                KERNEL_TAGS_TMP+=("flippy")
            else
                KERNEL_TAGS_TMP+=("stable")
            fi
        fi
    done
    # Deduplicate kernel tags
    KERNEL_TAGS=($(echo "${KERNEL_TAGS_TMP[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    echo -e "${INFO} Packaging directory: [ /opt/${SELECT_PACKITPATH} ]"
    echo -e "${INFO} Target devices: [ $(echo ${PACKAGE_OPENWRT[@]} | xargs) ]"
    echo -e "${INFO} Kernel tags: [ $(echo ${KERNEL_TAGS[@]} | xargs) ]"
    echo -e "${INFO} Kernel API endpoint: [ ${kernel_api} ]"

    # Override STABLE & FLIPPY kernel versions if custom versions are specified
    [[ -n "${KERNEL_VERSION_NAME}" && " ${KERNEL_TAGS[@]} " =~ (stable|flippy) ]] && {
        oldIFS="${IFS}"
        IFS="_"
        STABLE_KERNEL=(${KERNEL_VERSION_NAME})
        FLIPPY_KERNEL=(${KERNEL_VERSION_NAME})
        IFS="${oldIFS}"
        echo -e "${INFO} Using custom kernel version(s): [ $(echo ${STABLE_KERNEL[@]} | xargs) ]"
    }
}

init_packit_repo() {
    cd /opt

    # Clone the packaging repository (retry up to 10 times with 1-minute intervals)
    [[ -d "${SELECT_PACKITPATH}" ]] || {
        echo -e "${STEPS} Cloning repository [ ${SCRIPT_REPO_URL} ], branch [ ${SCRIPT_REPO_BRANCH} ] into [ ${SELECT_PACKITPATH} ]"
        for i in {1..10}; do
            git clone -q --single-branch --depth=1 --branch=${SCRIPT_REPO_BRANCH} ${SCRIPT_REPO_URL} ${SELECT_PACKITPATH}
            [[ "${?}" -eq "0" ]] && break || sleep 60
        done
        [[ -d "${SELECT_PACKITPATH}" ]] || error_msg "Failed to clone the packaging repository after 10 attempts."
    }

    # Validate the rootfs package path
    # Inherit the legacy variable name [ OPENWRT_ARMVIRT ] if [ OPENWRT_ARMSR ] is not set
    [[ -n "${OPENWRT_ARMVIRT}" && -z "${OPENWRT_ARMSR}" ]] && OPENWRT_ARMSR="${OPENWRT_ARMVIRT}"
    [[ -z "${OPENWRT_ARMSR}" ]] && error_msg "The OPENWRT_ARMSR variable is required but not set."

    # Load the rootfs.tar.gz package
    if [[ ! -f "${SELECT_PACKITPATH}/${PACKAGE_FILE}" ]]; then
        if [[ "${OPENWRT_ARMSR,,}" =~ ^http ]]; then
            echo -e "${STEPS} Downloading [ ${OPENWRT_ARMSR} ] to [ ${SELECT_PACKITPATH} ]"

            # Download the rootfs file (retry up to 10 times)
            download_retry "${OPENWRT_ARMSR}" "${SELECT_PACKITPATH}/${PACKAGE_FILE}"
            [[ "${?}" -eq "0" ]] || error_msg "Failed to download the OpenWrt rootfs file."
        else
            echo -e "${STEPS} Copying [ ${OPENWRT_ARMSR} ] to [ ${SELECT_PACKITPATH} ]"
            if [[ "${OPENWRT_ARMSR}" =~ ^/ ]]; then
                cp -vf ${OPENWRT_ARMSR} ${SELECT_PACKITPATH}/${PACKAGE_FILE} || true
            else
                cp -vf ${GITHUB_WORKSPACE}/${OPENWRT_ARMSR} ${SELECT_PACKITPATH}/${PACKAGE_FILE} || true
            fi
        fi
    else
        echo -e "${INFO} [ ${SELECT_PACKITPATH}/${PACKAGE_FILE} ] already exists, skipping download."
    fi

    # Validate rootfs file size (minimum 10MB)
    openwrt_rootfs_size="$(du -b "${SELECT_PACKITPATH}/${PACKAGE_FILE}" 2>/dev/null | awk '{print $1}')"
    if [[ "${openwrt_rootfs_size}" -ge "10485760" ]]; then
        human_size="$(awk "BEGIN{printf \"%.2f MB\", ${openwrt_rootfs_size}/1048576}")"
        echo -e "${INFO} [ ${SELECT_PACKITPATH}/${PACKAGE_FILE} ] loaded successfully."
        echo -e "${INFO} OpenWrt rootfs file size: [ ${human_size} ]"
    else
        error_msg "The [ ${SELECT_PACKITPATH}/${PACKAGE_FILE} ] failed to load (file is too small or corrupted)."
    fi

    # Modify default LAN IP address
    [[ "${OPENWRT_IP}" != "${OPENWRT_IP_DEFAULT_VALUE}" ]] && {
        echo -e "${STEPS} Modifying default LAN IP address to [ ${OPENWRT_IP} ]"
        tmpdir="$(mktemp -d)"
        tar -xzpf "${SELECT_PACKITPATH}/${PACKAGE_FILE}" -C "${tmpdir}"
        sed -i "/lan) ipad=\${ipaddr:-/s/\${ipaddr:-\"[^\"]*\"}/\${ipaddr:-\"${OPENWRT_IP}\"}/" "${tmpdir}/bin/config_generate"
        tar -czpf "${SELECT_PACKITPATH}/${PACKAGE_FILE}" -C "${tmpdir}" .
        rm -rf "${tmpdir}"
    }

    # Add custom packaging script
    [[ -n "${SCRIPT_DIY_PATH}" ]] && {
        rm -f ${SELECT_PACKITPATH}/${SCRIPT_DIY}
        if [[ "${SCRIPT_DIY_PATH,,}" =~ ^http ]]; then
            echo -e "${INFO} Downloading custom script: [ ${SCRIPT_DIY_PATH} ]"

            # Download the custom script file (retry up to 10 times)
            download_retry "${SCRIPT_DIY_PATH}" "${SELECT_PACKITPATH}/${SCRIPT_DIY}"
            [[ "${?}" -eq "0" ]] || error_msg "Failed to download the custom script file."
        else
            echo -e "${INFO} Copying custom script: [ ${SCRIPT_DIY_PATH} ]"
            cp -f ${GITHUB_WORKSPACE}/${SCRIPT_DIY_PATH} ${SELECT_PACKITPATH}/${SCRIPT_DIY}
            [[ "${?}" -eq "0" ]] || error_msg "Failed to copy the custom script file."
        fi
        chmod +x ${SELECT_PACKITPATH}/${SCRIPT_DIY}
        echo -e "Contents of [ ${SELECT_PACKITPATH} ] directory:\n $(ls -lh ${SELECT_PACKITPATH})"
    }
}

query_kernel() {
    echo -e "${STEPS} Querying latest kernel versions..."

    # Query kernel versions from the repository
    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Select kernel list by tag
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            elif [[ "${vb,,}" == "flippy" ]]; then
                down_kernel_list=(${FLIPPY_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Resolve latest version for each kernel series
            TMP_ARR_KERNELS=()
            i=1
            for kernel_var in "${down_kernel_list[@]}"; do
                echo -e "${INFO} (${i}) Querying latest version for [ ${vb} - ${kernel_var} ]"

                # Extract kernel VERSION.PATCHLEVEL, e.g. [ 6.1 ]
                kernel_verpatch="$(echo ${kernel_var} | awk -F '.' '{print $1"."$2}')"

                # Fetch latest kernel version from repository
                latest_version="$(
                    curl -fsSL \
                        ${kernel_api}/releases/expanded_assets/kernel_${vb} |
                        grep -oP "${kernel_verpatch}\.[0-9]+.*?(?=\.tar\.gz)" |
                        sort -urV | head -n 1
                )"

                if [[ "$?" -eq "0" && -n "${latest_version}" ]]; then
                    TMP_ARR_KERNELS[${i}]="${latest_version}"
                else
                    TMP_ARR_KERNELS[${i}]="${kernel_var}"
                fi

                echo -e "${INFO} (${i}) [ ${vb} - ${TMP_ARR_KERNELS[$i]} ] is the latest version."

                ((i++))
            done

            # Update kernel array with resolved latest versions
            if [[ "${vb,,}" == "rk3588" ]]; then
                RK3588_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest rk3588 kernel version(s): [ ${RK3588_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                RK35XX_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest rk35xx kernel version(s): [ ${RK35XX_KERNEL[@]} ]"
            elif [[ "${vb,,}" == "flippy" ]]; then
                FLIPPY_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest flippy kernel version(s): [ ${FLIPPY_KERNEL[@]} ]"
            else
                STABLE_KERNEL=(${TMP_ARR_KERNELS[@]})
                echo -e "${INFO} Latest stable kernel version(s): [ ${STABLE_KERNEL[@]} ]"
            fi

            ((x++))
        }
    done
}

check_kernel() {
    [[ -n "${1}" ]] && check_path="${1}" || error_msg "No kernel path specified for integrity check."
    check_files=($(cat "${check_path}/sha256sums" | awk '{print $2}'))
    m="1"
    for cf in "${check_files[@]}"; do
        {
            # Verify file exists
            [[ -s "${check_path}/${cf}" ]] || error_msg "Kernel file [ ${cf} ] is missing."
            # Verify SHA256 checksum
            tmp_sha256sum="$(sha256sum "${check_path}/${cf}" | awk '{print $1}')"
            tmp_checkcode="$(cat ${check_path}/sha256sums | grep ${cf} | awk '{print $1}')"
            [[ "${tmp_sha256sum,,}" == "${tmp_checkcode,,}" ]] || error_msg "[ ${cf} ]: SHA256 checksum verification failed."
            ((m++))
        }
    done
    echo -e "${INFO} All [ ${#check_files[@]} ] kernel files passed SHA256 integrity verification.\n"
}

download_kernel() {
    echo -e "${STEPS} Downloading kernel files..."

    cd /opt

    x="1"
    for vb in "${KERNEL_TAGS[@]}"; do
        {
            # Select kernel download list by tag
            if [[ "${vb,,}" == "rk3588" ]]; then
                down_kernel_list=(${RK3588_KERNEL[@]})
            elif [[ "${vb,,}" == "rk35xx" ]]; then
                down_kernel_list=(${RK35XX_KERNEL[@]})
            elif [[ "${vb,,}" == "flippy" ]]; then
                down_kernel_list=(${FLIPPY_KERNEL[@]})
            else
                down_kernel_list=(${STABLE_KERNEL[@]})
            fi

            # Ensure kernel storage directory exists
            kernel_path="kernel/${vb}"
            [[ -d "${kernel_path}" ]] || mkdir -p ${kernel_path}

            # Download and extract kernel files
            i="1"
            for kernel_var in "${down_kernel_list[@]}"; do
                if [[ ! -d "${kernel_path}/${kernel_var}" ]]; then
                    kernel_down_from="https://github.com/${KERNEL_REPO_URL}/releases/download/kernel_${vb}/${kernel_var}.tar.gz"
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Downloading kernel from [ ${kernel_down_from} ]"

                    # Download the kernel archive (retry up to 10 times)
                    download_retry "${kernel_down_from}" "${kernel_path}/${kernel_var}.tar.gz"
                    [[ "${?}" -eq "0" ]] || error_msg "Failed to download the kernel file after 10 attempts."

                    # Extract kernel archive
                    tar -mxf "${kernel_path}/${kernel_var}.tar.gz" -C "${kernel_path}"
                    [[ "${?}" -eq "0" ]] || error_msg "[ ${kernel_var} ] kernel extraction failed."
                else
                    echo -e "${INFO} (${x}.${i}) [ ${vb} - ${kernel_var} ] Kernel already exists locally, skipping download."
                fi

                # Verify file integrity if sha256sums is available
                [[ -f "${kernel_path}/${kernel_var}/sha256sums" ]] && check_kernel "${kernel_path}/${kernel_var}"

                ((i++))
            done

            # Clean up temporary archive files
            rm -f ${kernel_path}/*.tar.gz
            sync

            ((x++))
        }
    done
}

make_openwrt() {
    echo -e "${STEPS} Starting OpenWrt firmware packaging..."

    i="1"
    for PACKAGE_VAR in "${PACKAGE_OPENWRT[@]}"; do
        {
            # Select kernel based on device type
            if [[ " ${PACKAGE_OPENWRT_RK3588[@]} " =~ " ${PACKAGE_VAR} " ]]; then
                build_kernel=(${RK3588_KERNEL[@]})
                vb="rk3588"
            elif [[ " ${PACKAGE_OPENWRT_RK35XX[@]} " =~ " ${PACKAGE_VAR} " ]]; then
                build_kernel=(${RK35XX_KERNEL[@]})
                vb="rk35xx"
            else
                if [[ "${KERNEL_REPO_URL}" == "ophub/kernel" ]]; then
                    build_kernel=(${FLIPPY_KERNEL[@]})
                    vb="flippy"
                else
                    build_kernel=(${STABLE_KERNEL[@]})
                    vb="stable"
                fi
            fi

            k="1"
            for kernel_var in "${build_kernel[@]}"; do
                {
                    # Rockchip rk3568 series requires kernel 6.x.y or above
                    [[ -n "$(echo "${PACKAGE_OPENWRT_6XY[@]}" | grep -w "${PACKAGE_VAR}")" && "${kernel_var:0:2}" != "6." ]] && {
                        echo -e "${STEPS} (${i}.${k}) ${NOTE} Device requires kernel 6.x+, skipping [ ${PACKAGE_VAR} - ${vb}/${kernel_var} ] build."
                        ((k++))
                        continue
                    }

                    # Check available disk space
                    now_remaining_space="$(df -Tk /opt/${SELECT_PACKITPATH} | tail -n1 | awk '{print $5}' | echo $(($(xargs) / 1024 / 1024)))"
                    [[ "${now_remaining_space}" -le "3" ]] && {
                        echo -e "${WARNING} Insufficient disk space (< 3GB remaining). Aborting packaging. \n"
                        break
                    }

                    cd /opt/kernel

                    # Copy kernel files to working directory
                    rm -f *.tar.gz
                    cp -f ${vb}/${kernel_var}/* .
                    #
                    boot_kernel_file="$(ls boot-${kernel_var}* 2>/dev/null | head -n 1)"
                    KERNEL_VERSION="${boot_kernel_file:5:-7}"
                    [[ "${vb,,}" == "rk3588" ]] && RK3588_KERNEL_VERSION="${KERNEL_VERSION}" || RK3588_KERNEL_VERSION=""
                    [[ "${vb,,}" == "rk35xx" ]] && RK35XX_KERNEL_VERSION="${KERNEL_VERSION}" || RK35XX_KERNEL_VERSION=""
                    echo -e "${STEPS} (${i}.${k}) Start packaging OpenWrt: [ ${PACKAGE_VAR} ], Kernel directory: [ ${vb} ], Kernel version: [ ${KERNEL_VERSION} ]"
                    echo -e "${INFO} Available disk space: ${now_remaining_space}GB \n"

                    cd /opt/${SELECT_PACKITPATH}

                    # When SW_FLOWOFFLOAD is enabled, force-disable SFE_FLOW
                    [[ "${SW_FLOWOFFLOAD}" -eq "1" ]] && SFE_FLOW="0"

                    if [[ -n "${OPENWRT_VER}" && "${OPENWRT_VER,,}" == "auto" ]]; then
                        OPENWRT_VER="$(cat make.env | grep "OPENWRT_VER=\"" | cut -d '"' -f2)"
                        echo -e "${INFO} (${i}.${k}) OPENWRT_VER: [ ${OPENWRT_VER} ]"
                    fi

                    # Generate make.env configuration file
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

                    # Execute device-specific packaging script
                    case "${PACKAGE_VAR}" in
                        100ask-dshanpi-a1)  [[ -f "${SCRIPT_100ASKDSHANPIA1}" ]] && sudo ./${SCRIPT_100ASKDSHANPIA1} ;;
                        ak88)               [[ -f "${SCRIPT_H88K}" ]]            && sudo ./${SCRIPT_H88K} ;;
                        beikeyun)           [[ -f "${SCRIPT_BEIKEYUN}" ]]        && sudo ./${SCRIPT_BEIKEYUN} ;;
                        cm3)                [[ -f "${SCRIPT_CM3}" ]]             && sudo ./${SCRIPT_CM3} ;;
                        diy)                [[ -f "${SCRIPT_DIY}" ]]             && sudo ./${SCRIPT_DIY} ;;
                        e20c)               [[ -f "${SCRIPT_E20C}" ]]            && sudo ./${SCRIPT_E20C} ;;
                        e24c)               [[ -f "${SCRIPT_E24C}" ]]            && sudo ./${SCRIPT_E24C} ;;
                        e25)                [[ -f "${SCRIPT_E25}" ]]             && sudo ./${SCRIPT_E25} ;;
                        e52c)               [[ -f "${SCRIPT_E52C}" ]]            && sudo ./${SCRIPT_E52C} ;;
                        e54c)               [[ -f "${SCRIPT_E54C}" ]]            && sudo ./${SCRIPT_E54C} ;;
                        h28k)               [[ -f "${SCRIPT_H28K}" ]]            && sudo ./${SCRIPT_H28K} ;;
                        h66k)               [[ -f "${SCRIPT_H66K}" ]]            && sudo ./${SCRIPT_H66K} ;;
                        h68k)               [[ -f "${SCRIPT_H68K}" ]]            && sudo ./${SCRIPT_H68K} ;;
                        h69k)               [[ -f "${SCRIPT_H69K}" ]]            && sudo ./${SCRIPT_H69K} ;;
                        h69k-max)           [[ -f "${SCRIPT_H69K}" ]]            && sudo ./${SCRIPT_H69K} "max" ;;
                        h88k)               [[ -f "${SCRIPT_H88K}" ]]            && sudo ./${SCRIPT_H88K} "25" ;;
                        h88k-v3)            [[ -f "${SCRIPT_H88KV3}" ]]          && sudo ./${SCRIPT_H88KV3} ;;
                        ht2)                [[ -f "${SCRIPT_HT2}" ]]             && sudo ./${SCRIPT_HT2} ;;
                        jp-tvbox)           [[ -f "${SCRIPT_JPTVBOX}" ]]         && sudo ./${SCRIPT_JPTVBOX} ;;
                        l1pro)              [[ -f "${SCRIPT_L1PRO}" ]]           && sudo ./${SCRIPT_L1PRO} ;;
                        photonicat)         [[ -f "${SCRIPT_PHOTONICAT}" ]]      && sudo ./${SCRIPT_PHOTONICAT} ;;
                        qemu)               [[ -f "${SCRIPT_QEMU}" ]]            && sudo ./${SCRIPT_QEMU} ;;
                        r66s)               [[ -f "${SCRIPT_R66S}" ]]            && sudo ./${SCRIPT_R66S} ;;
                        r68s)               [[ -f "${SCRIPT_R68S}" ]]            && sudo ./${SCRIPT_R68S} ;;
                        rock5b)             [[ -f "${SCRIPT_ROCK5B}" ]]          && sudo ./${SCRIPT_ROCK5B} ;;
                        rock5c)             [[ -f "${SCRIPT_ROCK5C}" ]]          && sudo ./${SCRIPT_ROCK5C} ;;
                        s905)               [[ -f "${SCRIPT_S905}" ]]            && sudo ./${SCRIPT_S905} ;;
                        s905d)              [[ -f "${SCRIPT_S905D}" ]]           && sudo ./${SCRIPT_S905D} ;;
                        s905x2)             [[ -f "${SCRIPT_S905X2}" ]]          && sudo ./${SCRIPT_S905X2} ;;
                        s905x3)             [[ -f "${SCRIPT_S905X3}" ]]          && sudo ./${SCRIPT_S905X3} ;;
                        s912)               [[ -f "${SCRIPT_S912}" ]]            && sudo ./${SCRIPT_S912} ;;
                        s922x)              [[ -f "${SCRIPT_S922X}" ]]           && sudo ./${SCRIPT_S922X} ;;
                        s922x-n2)           [[ -f "${SCRIPT_S922X_N2}" ]]        && sudo ./${SCRIPT_S922X_N2} ;;
                        vplus)              [[ -f "${SCRIPT_VPLUS}" ]]           && sudo ./${SCRIPT_VPLUS} ;;
                        watermelon-pi)      [[ -f "${SCRIPT_WATERMELONPI}" ]]    && sudo ./${SCRIPT_WATERMELONPI} ;;
                        yixun-rs6pro)       [[ -f "${SCRIPT_RS6PRO}" ]]          && sudo ./${SCRIPT_RS6PRO} ;;
                        zcube1-max)         [[ -f "${SCRIPT_ZCUBE1MAX}" ]]       && sudo ./${SCRIPT_ZCUBE1MAX} ;;
                        rk3399)             [[ -f "${SCRIPT_RK3399}" && ${#RK3399_BOARD_LIST[@]} -gt 0 ]] && {
                                                for rbl in ${!RK3399_BOARD_LIST[@]}; do
                                                    sudo ./${SCRIPT_RK3399} ${RK3399_BOARD_LIST[rbl]} ${RK3399_DTB_LIST[rbl]}
                                                done
                                            } ;;
                        *)                  echo -e "${WARNING} Unsupported SoC [ ${PACKAGE_VAR} ], skipping." && continue ;;
                    esac

                    # Compress output images
                    img_num="$(ls /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}/*.img 2>/dev/null | wc -l)"
                    [[ "${img_num}" -ne "0" ]] && {
                        echo -e "${STEPS} (${i}.${k}) Compressing firmware images in [ ${SELECT_OUTPUTPATH} ]"
                        cd /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}
                        case "${GZIP_IMGS}" in
                            7z | .7z)      ls *.img | head -n 1 | xargs -I % sh -c 'sudo 7z a -t7z -r %.7z %; rm -f %' ;;
                            xz | .xz)      sudo xz -z *.img ;;
                            zip | .zip)    ls *.img | head -n 1 | xargs -I % sh -c 'sudo zip %.zip %; rm -f %' ;;
                            zst | .zst)    sudo zstd --rm *.img ;;
                            gz | .gz | *)  sudo pigz -f *.img ;;
                        esac
                    }

                    echo -e "${SUCCESS} (${i}.${k}) OpenWrt packaged successfully: [ ${PACKAGE_VAR} - ${vb} - ${kernel_var} ] \n"
                    sync

                    ((k++))
                }
            done

            ((i++))
        }
    done

    echo -e "${SUCCESS} All devices packaged successfully. \n"
}

out_github_env() {
    echo -e "${STEPS} Exporting GitHub Actions environment variables..."
    if [[ -d "/opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}" ]]; then

        cd /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}

        if [[ "${SAVE_OPENWRT_ROOTFS,,}" =~ ^(true|yes)$ ]]; then
            echo -e "${INFO} Copying [ ${PACKAGE_FILE} ] to [ ${SELECT_OUTPUTPATH} ]"
            sudo cp -f ../${PACKAGE_FILE} . || true
        fi

        # Generate SHA256 checksum files for each OpenWrt image
        #for file in *; do [[ -f "${file}" ]] && sudo sha256sum "${file}" | sudo tee "${file}.sha" >/dev/null; done
        #sudo rm -f *.sha.sha 2>/dev/null

        echo "PACKAGED_OUTPUTPATH=${PWD}" >>${GITHUB_ENV}
        echo "PACKAGED_OUTPUTDATE=$(date +"%m.%d.%H%M")" >>${GITHUB_ENV}
        echo "PACKAGED_STATUS=success" >>${GITHUB_ENV}
        echo -e "PACKAGED_OUTPUTPATH: ${PWD}"
        echo -e "PACKAGED_OUTPUTDATE: $(date +"%m.%d.%H%M")"
        echo -e "PACKAGED_STATUS: success"
        echo -e "${INFO} Output directory contents:"
        echo -e "$(ls -lh /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH} 2>/dev/null) \n"
    else
        echo -e "${ERROR} Packaging failed: output directory not found. \n"
        echo "PACKAGED_STATUS=failure" >>${GITHUB_ENV}
    fi
}
# Show welcome message
echo -e "${STEPS} Welcome to the OpenWrt Packaging Tool! \n"
echo -e "${INFO} Server CPU information: \n$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c) \n"

# Initialize variables and repository
init_var
init_packit_repo

# Display pre-build disk usage
echo -e "${INFO} Disk usage before packaging:\n$(df -hT /opt/${SELECT_PACKITPATH}) \n"

# Package OpenWrt firmware
[[ "${KERNEL_AUTO_LATEST,,}" =~ ^(true|yes)$ ]] && query_kernel
download_kernel
make_openwrt
out_github_env

# Display post-build disk usage
echo -e "${INFO} Disk usage after packaging:\n$(df -hT /opt/${SELECT_PACKITPATH}) \n"
echo -e "${SUCCESS} OpenWrt packaging process completed successfully. \n"
