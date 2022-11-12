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
PACKAGE_FILE="openwrt-armvirt-64-default-rootfs.tar.gz"
PACKAGE_SOC_VALUE="all"

# Set the list of supported device
PACKAGE_OPENWRT=(
    "rock5b" "h88k"
    "vplus"
    "beikeyun" "l1pro" "r66s" "r68s" "h68k" "e25"
    "s922x" "s922x-n2" "s905x3" "s905x2" "s912" "s905d" "s905"
    "qemu"
    "diy"
)
# Set the list of devices using the rk3588 kernel
PACKAGE_OPENWRT_RK3588=(
    "rock5b" "h88k"
)

# Set the default packaged kernel download repository
KERNEL_REPO_URL_VALUE="https://github.com/breakings/OpenWrt/tree/main/opt"
# Common kernel directory, RK3588 kernel directory, [ rk3588 ] is the fixed name
KERNEL_DIR=("kernel" "rk3588")
COMMON_KERNEL=("6.0.1" "5.15.50")
RK3588_KERNEL=("5.10.150")
KERNEL_AUTO_LATEST_VALUE="true"

# Set the working directory under /opt
SELECT_PACKITPATH_VALUE="openwrt_packit"
SELECT_OUTPUTPATH_VALUE="output"
GZIP_IMGS_VALUE="auto"
SAVE_OPENWRT_ARMVIRT_VALUE="true"

# Set the default packaging script
SCRIPT_VPLUS_FILE="mk_h6_vplus.sh"
SCRIPT_BEIKEYUN_FILE="mk_rk3328_beikeyun.sh"
SCRIPT_L1PRO_FILE="mk_rk3328_l1pro.sh"
SCRIPT_R66S_FILE="mk_rk3568_r66s.sh"
SCRIPT_R68S_FILE="mk_rk3568_r68s.sh"
SCRIPT_H68K_FILE="mk_rk3568_h68k.sh"
SCRIPT_E25_FILE="mk_rk3568_e25.sh"
SCRIPT_ROCK5B_FILE="mk_rk3588_rock5b.sh"
SCRIPT_H88K_FILE="mk_rk3588_h88k.sh"
SCRIPT_S905_FILE="mk_s905_mxqpro+.sh"
SCRIPT_S905D_FILE="mk_s905d_n1.sh"
SCRIPT_S905X2_FILE="mk_s905x2_x96max.sh"
SCRIPT_S905X3_FILE="mk_s905x3_multi.sh"
SCRIPT_S912_FILE="mk_s912_zyxq.sh"
SCRIPT_S922X_FILE="mk_s922x_gtking.sh"
SCRIPT_S922X_N2_FILE="mk_s922x_odroid-n2.sh"
SCRIPT_QEMU_FILE="mk_qemu-aarch64_img.sh"
SCRIPT_DIY_FILE="mk_diy.sh"

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

# Set font color
blue_font_prefix="\033[94m"
purple_font_prefix="\033[95m"
green_font_prefix="\033[92m"
yellow_font_prefix="\033[93m"
red_font_prefix="\033[91m"
font_color_suffix="\033[0m"
INFO="[${blue_font_prefix}INFO${font_color_suffix}]"
STEPS="[${purple_font_prefix}STEPS${font_color_suffix}]"
SUCCESS="[${green_font_prefix}SUCCESS${font_color_suffix}]"
WARNING="[${yellow_font_prefix}WARNING${font_color_suffix}]"
ERROR="[${red_font_prefix}ERROR${font_color_suffix}]"
#
#==============================================================================================

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

init_var() {
    # Install the compressed package
    sudo apt-get -qq update && sudo apt-get -qq install -y p7zip p7zip-full zip unzip gzip xz-utils pigz zstd subversion git

    # Specify the default value
    [[ -n "${SCRIPT_REPO_URL}" ]] || SCRIPT_REPO_URL="${SCRIPT_REPO_URL_VALUE}"
    [[ "${SCRIPT_REPO_URL}" == http* ]] || SCRIPT_REPO_URL="https://github.com/${SCRIPT_REPO_URL}"
    [[ -n "${SCRIPT_REPO_BRANCH}" ]] || SCRIPT_REPO_BRANCH="${SCRIPT_REPO_BRANCH_VALUE}"
    [[ -n "${KERNEL_REPO_URL}" ]] || KERNEL_REPO_URL="${KERNEL_REPO_URL_VALUE}"
    [[ "${KERNEL_REPO_URL}" == http* ]] || KERNEL_REPO_URL="https://github.com/${KERNEL_REPO_URL}"
    [[ -n "${PACKAGE_SOC}" ]] || PACKAGE_SOC="${PACKAGE_SOC_VALUE}"
    [[ -n "${KERNEL_AUTO_LATEST}" ]] || KERNEL_AUTO_LATEST="${KERNEL_AUTO_LATEST_VALUE}"
    [[ -n "${GZIP_IMGS}" ]] || GZIP_IMGS="${GZIP_IMGS_VALUE}"
    [[ -n "${SELECT_PACKITPATH}" ]] || SELECT_PACKITPATH="${SELECT_PACKITPATH_VALUE}"
    [[ -n "${SELECT_OUTPUTPATH}" ]] || SELECT_OUTPUTPATH="${SELECT_OUTPUTPATH_VALUE}"
    [[ -n "${SAVE_OPENWRT_ARMVIRT}" ]] || SAVE_OPENWRT_ARMVIRT="${SAVE_OPENWRT_ARMVIRT_VALUE}"

    # Specify the default packaging script
    [[ -n "${SCRIPT_VPLUS}" ]] || SCRIPT_VPLUS="${SCRIPT_VPLUS_FILE}"
    [[ -n "${SCRIPT_BEIKEYUN}" ]] || SCRIPT_BEIKEYUN="${SCRIPT_BEIKEYUN_FILE}"
    [[ -n "${SCRIPT_L1PRO}" ]] || SCRIPT_L1PRO="${SCRIPT_L1PRO_FILE}"
    [[ -n "${SCRIPT_R66S}" ]] || SCRIPT_R66S="${SCRIPT_R66S_FILE}"
    [[ -n "${SCRIPT_R68S}" ]] || SCRIPT_R68S="${SCRIPT_R68S_FILE}"
    [[ -n "${SCRIPT_H68K}" ]] || SCRIPT_H68K="${SCRIPT_H68K_FILE}"
    [[ -n "${SCRIPT_E25}" ]] || SCRIPT_E25="${SCRIPT_E25_FILE}"
    [[ -n "${SCRIPT_ROCK5B}" ]] || SCRIPT_ROCK5B="${SCRIPT_ROCK5B_FILE}"
    [[ -n "${SCRIPT_H88K}" ]] || SCRIPT_H88K="${SCRIPT_H88K_FILE}"
    [[ -n "${SCRIPT_S905}" ]] || SCRIPT_S905="${SCRIPT_S905_FILE}"
    [[ -n "${SCRIPT_S905D}" ]] || SCRIPT_S905D="${SCRIPT_S905D_FILE}"
    [[ -n "${SCRIPT_S905X2}" ]] || SCRIPT_S905X2="${SCRIPT_S905X2_FILE}"
    [[ -n "${SCRIPT_S905X3}" ]] || SCRIPT_S905X3="${SCRIPT_S905X3_FILE}"
    [[ -n "${SCRIPT_S912}" ]] || SCRIPT_S912="${SCRIPT_S912_FILE}"
    [[ -n "${SCRIPT_S922X}" ]] || SCRIPT_S922X="${SCRIPT_S922X_FILE}"
    [[ -n "${SCRIPT_S922X_N2}" ]] || SCRIPT_S922X_N2="${SCRIPT_S922X_N2_FILE}"
    [[ -n "${SCRIPT_QEMU}" ]] || SCRIPT_QEMU="${SCRIPT_QEMU_FILE}"
    [[ -n "${SCRIPT_DIY}" ]] || SCRIPT_DIY="${SCRIPT_DIY_FILE}"

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

    # Reset KERNEL_DIR options
    if [[ -n "${KERNEL_VERSION_DIR}" ]]; then
        unset KERNEL_DIR
        oldIFS=$IFS
        IFS=_
        KERNEL_DIR=(${KERNEL_VERSION_DIR})
        IFS=$oldIFS
    fi

    # Reset COMMON_KERNEL options
    if [[ -n "${KERNEL_VERSION_NAME}" ]]; then
        unset COMMON_KERNEL
        oldIFS=$IFS
        IFS=_
        COMMON_KERNEL=(${KERNEL_VERSION_NAME})
        IFS=$oldIFS
    fi

    # Confirm package object
    if [[ -n "${PACKAGE_SOC}" && "${PACKAGE_SOC}" != "all" ]]; then
        unset PACKAGE_OPENWRT
        oldIFS=$IFS
        IFS=_
        PACKAGE_OPENWRT=(${PACKAGE_SOC})
        IFS=$oldIFS
    fi
    echo -e "${INFO} Package OpenWrt SoC List: [ ${PACKAGE_OPENWRT[*]} ]"
}

init_packit_repo() {
    cd /opt

    # clone ${SELECT_PACKITPATH} repo
    echo -e "${STEPS} Cloning package script repository [ ${SCRIPT_REPO_URL} ], branch [ ${SCRIPT_REPO_BRANCH} ] into ${SELECT_PACKITPATH}."
    git clone --depth 1 ${SCRIPT_REPO_URL} -b ${SCRIPT_REPO_BRANCH} ${SELECT_PACKITPATH}

    # Check the *rootfs.tar.gz package
    [[ -z "${OPENWRT_ARMVIRT}" ]] && error_msg "The [ OPENWRT_ARMVIRT ] variable must be specified."

    # Load *-armvirt-64-default-rootfs.tar.gz
    if [[ "${OPENWRT_ARMVIRT}" == http* ]]; then
        echo -e "${STEPS} wget [ ${OPENWRT_ARMVIRT} ] file into ${SELECT_PACKITPATH}"
        wget ${OPENWRT_ARMVIRT} -q -O "${SELECT_PACKITPATH}/${PACKAGE_FILE}"
    else
        echo -e "${STEPS} copy [ ${GITHUB_WORKSPACE}/${OPENWRT_ARMVIRT} ] file into ${SELECT_PACKITPATH}"
        cp -f ${GITHUB_WORKSPACE}/${OPENWRT_ARMVIRT} ${SELECT_PACKITPATH}/${PACKAGE_FILE}
    fi

    # Normal ${PACKAGE_FILE} file should not be less than 10MB
    armvirt_rootfs_size="$(ls -l ${SELECT_PACKITPATH}/${PACKAGE_FILE} 2>/dev/null | awk '{print $5}')"
    echo -e "${INFO} armvirt_rootfs_size: [ ${armvirt_rootfs_size} ]"
    if [[ "${armvirt_rootfs_size}" -ge "10000000" ]]; then
        echo -e "${INFO} ${SELECT_PACKITPATH}/${PACKAGE_FILE} loaded successfully."
    else
        error_msg "The [ ${SELECT_PACKITPATH}/${PACKAGE_FILE} ] failed to load."
    fi
}

download_kernel() {
    cd /opt

    # KERNEL_REPO_URL URL format conversion to support svn co
    if [[ "${KERNEL_REPO_URL}" == http* && -n "$(echo ${KERNEL_REPO_URL} | grep "tree")" ]]; then
        # Left part
        KERNEL_REPO_URL_LEFT="${KERNEL_REPO_URL%\/tree*}"
        # Right part
        KERNEL_REPO_URL_RIGHT="${KERNEL_REPO_URL#*tree\/}"
        KERNEL_REPO_URL_RIGHT="${KERNEL_REPO_URL_RIGHT#*\/}"
        KERNEL_REPO_URL="${KERNEL_REPO_URL_LEFT}/trunk/${KERNEL_REPO_URL_RIGHT}"
    fi
    # Process the previous address, remove the [ /kernel ] directory
    KERNEL_REPO_URL="${KERNEL_REPO_URL//opt\/kernel/opt}"

    # Convert to api method
    SERVER_KERNEL_URL="${KERNEL_REPO_URL#*com\/}"
    SERVER_KERNEL_URL="${SERVER_KERNEL_URL//trunk/contents}"
    SERVER_KERNEL_URL="https://api.github.com/repos/${SERVER_KERNEL_URL}"

    # Check the version on the kernel library
    if [[ -n "${KERNEL_AUTO_LATEST}" && "${KERNEL_AUTO_LATEST}" == "true" ]]; then
        x="1"
        for vb in ${KERNEL_DIR[*]}; do

            TMP_ARR_KERNELS=()

            # Select the corresponding kernel directory and list
            if [[ "${vb}" == "rk3588" ]]; then
                down_kernel_list="${RK3588_KERNEL[*]}"
            else
                down_kernel_list="${COMMON_KERNEL[*]}"
            fi

            i=1
            for KERNEL_VAR in ${down_kernel_list[*]}; do
                echo -e "${INFO} (${i}) Auto query the latest kernel version of the same series for [ ${KERNEL_VAR} ]"
                MAIN_LINE="$(echo ${KERNEL_VAR} | awk -F '.' '{print $1"."$2}')"
                # Check the version on the server (e.g LATEST_VERSION="125")
                LATEST_VERSION="$(curl -s "${SERVER_KERNEL_URL}/${vb}" | grep "name" | grep -oE "${MAIN_LINE}.[0-9]+" | sed -e "s/${MAIN_LINE}.//g" | sort -n | sed -n '$p')"
                if [[ "$?" -eq "0" && -n "${LATEST_VERSION}" ]]; then
                    TMP_ARR_KERNELS[${i}]="${MAIN_LINE}.${LATEST_VERSION}"
                else
                    TMP_ARR_KERNELS[${i}]="${KERNEL_VAR}"
                fi
                echo -e "${INFO} (${i}) [ ${vb} - ${TMP_ARR_KERNELS[$i]} ] is latest kernel."

                let i++
            done

            # Reset the kernel array to the latest kernel version
            if [[ "${vb}" == "rk3588" ]]; then
                unset RK3588_KERNEL
                RK3588_KERNEL="${TMP_ARR_KERNELS[*]}"
            else
                unset COMMON_KERNEL
                COMMON_KERNEL="${TMP_ARR_KERNELS[*]}"
            fi
            down_kernel_list="${TMP_ARR_KERNELS[*]}"

            # Kernel storage directory
            kernel_path="kernel/${vb}"
            [[ -d "${kernel_path}" ]] || mkdir -p ${kernel_path}

            # Download the kernel to the storage directory
            i="1"
            for KERNEL_VAR in ${down_kernel_list[*]}; do
                if [[ "$(ls ${kernel_path}/*${KERNEL_VAR}*.tar.gz -l 2>/dev/null | grep "^-" | wc -l)" -lt "3" ]]; then
                    echo -e "${INFO} (${i}) [ ${vb} - ${KERNEL_VAR} ] Kernel loading from [ ${KERNEL_REPO_URL/trunk/tree\/main}/${vb}/${KERNEL_VAR} ]"
                    svn export ${KERNEL_REPO_URL}/${vb}/${KERNEL_VAR} ${kernel_path}/${KERNEL_VAR} --force
                else
                    echo -e "${INFO} (${i}) [ ${vb} - ${KERNEL_VAR} ] Kernel is in the local directory."
                fi

                let i++
            done
            sync

            let x++
        done
    fi

    echo -e "${INFO} Package OpenWrt Common Kernel List: [ ${COMMON_KERNEL[*]} ]"
    echo -e "${INFO} Package OpenWrt RK3588 Kernel List: [ ${RK3588_KERNEL[*]} ]"
}

make_openwrt() {
    # Packaged OpenWrt
    echo -e "${STEPS} Start packaging openwrt..."

    i="1"
    for PACKAGE_VAR in ${PACKAGE_OPENWRT[*]}; do
        {
            if [[ -n "$(echo "${PACKAGE_OPENWRT_RK3588[@]}" | grep -w "${PACKAGE_VAR}")" ]]; then
                build_kernel="${RK3588_KERNEL[*]}"
                vb="rk3588"
            else
                build_kernel="${COMMON_KERNEL[*]}"
                vb="$(echo "${KERNEL_DIR[@]}" | sed -e "s|rk3588||" | xargs)"
            fi
            echo -e "${INFO} (${i}) OpenWrt name: [ ${PACKAGE_VAR} ]"
            echo -e "${INFO} (${i}) Kernel directory: [ ${vb} ], Kernel list: ${build_kernel[*]}"

            k="1"
            for KERNEL_VAR in ${build_kernel[*]}; do
                {

                    cd /opt/kernel

                    # Copy the kernel to the packaging directory
                    rm -f *.tar.gz
                    cp -f ${vb}/${KERNEL_VAR}/* .
                    #
                    boot_kernel_file="$(ls boot-${KERNEL_VAR}* 2>/dev/null | head -n 1)"
                    boot_kernel_file="${boot_kernel_file//boot-/}"
                    boot_kernel_file="${boot_kernel_file//.tar.gz/}"
                    [[ "${vb}" == "rk3588" ]] && rk3588_file="${boot_kernel_file}" || rk3588_file=""
                    echo -e "${INFO} (${i}.${k}) KERNEL_VERSION: ${boot_kernel_file}"

                    cd /opt/${SELECT_PACKITPATH}

                    # If flowoffload is turned on, then sfe is forced to be closed by default
                    [[ "${SW_FLOWOFFLOAD}" -eq "1" ]] && SFE_FLOW=0

                    if [[ -n "${OPENWRT_VER}" && "${OPENWRT_VER}" == "auto" ]]; then
                        OPENWRT_VER="$(cat make.env | grep "OPENWRT_VER=\"" | cut -d '"' -f2)"
                        echo -e "${INFO} (${i}.${k}) OPENWRT_VER: ${OPENWRT_VER}"
                    fi

                    rm -f make.env 2>/dev/null
                    cat >make.env <<EOF
WHOAMI="${WHOAMI}"
OPENWRT_VER="${OPENWRT_VER}"
RK3588_KERNEL_VERSION="${rk3588_file}"
KERNEL_VERSION="${boot_kernel_file}"
KERNEL_PKG_HOME="/opt/kernel"
SW_FLOWOFFLOAD="${SW_FLOWOFFLOAD}"
HW_FLOWOFFLOAD="${HW_FLOWOFFLOAD}"
SFE_FLOW="${SFE_FLOW}"
ENABLE_WIFI_K504="${ENABLE_WIFI_K504}"
ENABLE_WIFI_K510="${ENABLE_WIFI_K510}"
DISTRIB_REVISION="${DISTRIB_REVISION}"
DISTRIB_DESCRIPTION="${DISTRIB_DESCRIPTION}"
EOF

                    echo -e "${INFO} make.env file info:"
                    cat make.env

                    echo -e "${STEPS} (${i}.${k}) Start packaging OpenWrt: [ ${PACKAGE_VAR} ], Kernel directory: [ ${vb} ], Kernel name: [ ${KERNEL_VAR} ]"

                    now_remaining_space="$(df -Tk ${PWD} | grep '/dev/' | awk '{print $5}' | echo $(($(xargs) / 1024 / 1024)))"
                    if [[ "${now_remaining_space}" -le "3" ]]; then
                        echo -e "${WARNING} If the remaining space is less than 3G, exit this packaging. \n"
                        break 2
                    else
                        echo -e "${INFO} Remaining space is ${now_remaining_space}G. \n"
                    fi

                    case "${PACKAGE_VAR}" in
                        vplus)    [[ -f "${SCRIPT_VPLUS}" ]] && sudo ./${SCRIPT_VPLUS} ;;
                        beikeyun) [[ -f "${SCRIPT_BEIKEYUN}" ]] && sudo ./${SCRIPT_BEIKEYUN} ;;
                        l1pro)    [[ -f "${SCRIPT_L1PRO}" ]] && sudo ./${SCRIPT_L1PRO} ;;
                        r66s)     [[ -f "${SCRIPT_R66S}" ]] && sudo ./${SCRIPT_R66S} ;;
                        r68s)     [[ -f "${SCRIPT_R68S}" ]] && sudo ./${SCRIPT_R68S} ;;
                        h68k)     [[ -f "${SCRIPT_H68K}" ]] && sudo ./${SCRIPT_H68K} ;;
                        rock5b)   [[ -f "${SCRIPT_ROCK5B}" ]] && sudo ./${SCRIPT_ROCK5B} ;;
                        h88k)     [[ -f "${SCRIPT_H88K}" ]] && sudo ./${SCRIPT_H88K} ;;
                        e25)      [[ -f "${SCRIPT_E25}" ]] && sudo ./${SCRIPT_E25} ;;
                        s905)     [[ -f "${SCRIPT_S905}" ]] && sudo ./${SCRIPT_S905} ;;
                        s905d)    [[ -f "${SCRIPT_S905D}" ]] && sudo ./${SCRIPT_S905D} ;;
                        s905x2)   [[ -f "${SCRIPT_S905X2}" ]] && sudo ./${SCRIPT_S905X2} ;;
                        s905x3)   [[ -f "${SCRIPT_S905X3}" ]] && sudo ./${SCRIPT_S905X3} ;;
                        s912)     [[ -f "${SCRIPT_S912}" ]] && sudo ./${SCRIPT_S912} ;;
                        s922x)    [[ -f "${SCRIPT_S922X}" ]] && sudo ./${SCRIPT_S922X} ;;
                        s922x-n2) [[ -f "${SCRIPT_S922X_N2}" ]] && sudo ./${SCRIPT_S922X_N2} ;;
                        qemu)     [[ -f "${SCRIPT_QEMU}" ]] && sudo ./${SCRIPT_QEMU} ;;
                        diy)      [[ -f "${SCRIPT_DIY}" ]] && sudo ./${SCRIPT_DIY} ;;
                        *)        echo -e "${WARNING} Have no this SoC. Skipped."
                                  continue ;;
                    esac
                    echo -e "${SUCCESS} (${i}.${k}) Package openwrt completed."

                    echo -e "${STEPS} Compress the .img file in the [ ${SELECT_OUTPUTPATH} ] directory. \n"
                    cd /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}
                    case "${GZIP_IMGS}" in
                        7z | .7z)      ls *.img | head -n 1 | xargs -I % sh -c '7z a -t7z -r %.7z %; rm -f %' ;;
                        zip | .zip)    ls *.img | head -n 1 | xargs -I % sh -c 'zip %.zip %; rm -f %' ;;
                        zst | .zst)    zstd --rm *.img ;;
                        xz | .xz)      xz -z *.img ;;
                        gz | .gz | *)  pigz -9f *.img ;;
                    esac
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
    echo -e "${STEPS} Output environment variables."
    if [[ -d "/opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}" ]]; then

        cd /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH}

        if [[ "${SAVE_OPENWRT_ARMVIRT}" == "true" ]]; then
            echo -e "${STEPS} copy ${PACKAGE_FILE} files into ${SELECT_OUTPUTPATH} folder."
            cp -f ../${PACKAGE_FILE} .
        fi

        # Generate sha256sum check file
        sha256sum * >sha256sums && sync

        echo "PACKAGED_OUTPUTPATH=${PWD}" >>$GITHUB_ENV
        echo "PACKAGED_OUTPUTDATE=$(date +"%m.%d.%H%M")" >>$GITHUB_ENV
        echo "PACKAGED_STATUS=success" >>$GITHUB_ENV
        echo -e "PACKAGED_OUTPUTPATH: ${PWD}"
        echo -e "PACKAGED_OUTPUTDATE: $(date +"%m.%d.%H%M")"
        echo -e "PACKAGED_STATUS: success"
        echo -e "${INFO} PACKAGED_OUTPUTPATH files list:"
        echo -e "$(ls /opt/${SELECT_PACKITPATH}/${SELECT_OUTPUTPATH} 2>/dev/null) \n"
    else
        echo -e "${ERROR} Packaging failed. \n"
        echo "PACKAGED_STATUS=failure" >>$GITHUB_ENV
    fi
}

# Show server free space
echo -e "${STEPS} Welcome to use the OpenWrt packaging tool! \n"
echo -e "${INFO} Server CPU configuration information: \n$(cat /proc/cpuinfo | grep name | cut -f2 -d: | uniq -c) \n"
echo -e "${INFO} Server memory usage: \n$(free -h) \n"
echo -e "${INFO} Server space usage before starting to compile:\n$(df -hT ${PWD}) \n"

# Perform related operations in sequence
init_var
init_packit_repo
download_kernel
make_openwrt
out_github_env

# Display the remaining space on the server
echo -e "${INFO} Server space usage after compilation:\n$(df -hT ${PWD}) \n"
echo -e "${STEPS} The packaging process has been completed. \n"
