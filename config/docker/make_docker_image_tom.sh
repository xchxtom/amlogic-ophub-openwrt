#!/bin/bash
#================================================================================================
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of the make OpenWrt
# https://github.com/ophub/amlogic-s9xxx-openwrt
#
# Description: Creating a Docker Image
# Copyright (C) 2021~ https://github.com/unifreq/openwrt_packit
# Copyright (C) 2021~ https://github.com/ophub/amlogic-s9xxx-openwrt
#
# Command: ./config/docker/make_docker_image.sh
#
#======================================== Functions list ========================================
#
# error_msg         : Output error message
# check_depends     : Check dependencies
# find_openwrt      : Find OpenWrt file (openwrt/*rootfs.tar.gz)
# adjust_settings   : Adjust related file settings
# make_dockerimg    : make docker image
#
#================================ Set make environment variables ================================
#
# Set default parameters
current_path="${PWD}"
openwrt_path="${current_path}/openwrt"
openwrt_rootfs_file="*rootfs.tar.gz"
docker_rootfs_file="openwrt-docker-armsr-armv8-default-rootfs.tar.gz"
docker_path="${current_path}/config/docker"
make_path="${current_path}/make-openwrt"
common_files="${make_path}/openwrt-files/common-files"
tmp_path="${current_path}/tmp"
out_path="${current_path}/out"

# Set default parameters
STEPS="[\033[95m STEPS \033[0m]"
INFO="[\033[94m INFO \033[0m]"
SUCCESS="[\033[92m SUCCESS \033[0m]"
WARNING="[\033[93m WARNING \033[0m]"
ERROR="[\033[91m ERROR \033[0m]"
#
#================================================================================================

error_msg() {
    echo -e "${ERROR} ${1}"
    exit 1
}

check_depends() {
    # Check the necessary dependencies
    is_dpkg="0"
    dpkg_packages=("tar" "gzip")
    i="1"
    for package in ${dpkg_packages[*]}; do
        [[ -n "$(dpkg -l | awk '{print $2}' | grep -w "^${package}$" 2>/dev/null)" ]] || is_dpkg="1"
        let i++
    done

    # Install missing packages
    if [[ "${is_dpkg}" -eq "1" ]]; then
        echo -e "${STEPS} Start installing the necessary dependencies..."
        sudo apt-get update
        sudo apt-get install -y ${dpkg_packages[*]}
        [[ "${?}" -ne "0" ]] && error_msg "Dependency installation failed."
    fi
}

find_openwrt() {
    cd ${current_path}
    echo -e "${STEPS} Start searching for OpenWrt file..."

    # Find whether the OpenWrt file exists
    openwrt_file_name="$(ls ${openwrt_path}/${openwrt_rootfs_file} 2>/dev/null | head -n 1 | awk -F "/" '{print $NF}')"
    if [[ -n "${openwrt_file_name}" ]]; then
        echo -e "${INFO} OpenWrt file: [ ${openwrt_file_name} ]"
    else
        error_msg "There is no [ ${openwrt_rootfs_file} ] file in the [ ${openwrt_path} ] directory."
    fi

    # Check whether the Dockerfile exists
    [[ -f "${docker_path}/Dockerfile" ]] || error_msg "Missing Dockerfile."
}

adjust_settings() {
    cd ${current_path}
    echo -e "${STEPS} Start adjusting OpenWrt file settings..."

    echo -e "${INFO} Unpack Openwrt."
    rm -rf ${tmp_path} && mkdir -p ${tmp_path}
    tar -xzf ${openwrt_path}/${openwrt_file_name} -C ${tmp_path}

    # Remove unused files
    echo -e "${INFO} Remove useless files."
    rm -rf ${tmp_path}/lib/firmware/*
    rm -rf ${tmp_path}/lib/modules/*
    rm -f ${tmp_path}/root/.todo_rootfs_resize
    find ${tmp_path} -name '*.rej' -exec rm {} \;
    find ${tmp_path} -name '*.orig' -exec rm {} \;
    # Remove Amlogic Service
    rm -f ${tmp_path}/usr/lib/lua/luci/controller/amlogic.lua
    rm -rf ${tmp_path}/usr/lib/lua/luci/model/cbi/amlogic
    rm -rf ${tmp_path}/usr/share/amlogic
    rm -f ${tmp_path}/usr/sbin/openwrt-*-*
    rm -f ${tmp_path}/etc/init.d/amlogic
    # Remove docker Service
    #rm -f ${tmp_path}/usr/lib/lua/luci/controller/docker*
    #rm -rf ${tmp_path}/usr/lib/lua/luci/model/cbi/docker*
    #rm -f ${tmp_path}/usr/lib/lua/luci/model/docker*
    #rm -f ${tmp_path}/usr/bin/docker*
    #rm -f ${tmp_path}/etc/init.d/docker*

    # Turn off hw_flow by default
    [[ -f "${tmp_path}/etc/config/turboacc" ]] && {
        echo -e "${INFO} Adjust turboacc settings."
        sed -i "s|option hw_flow.*|option hw_flow '0'|g" ${tmp_path}/etc/config/turboacc
        sed -i "s|option sw_flow.*|option sw_flow '0'|g" ${tmp_path}/etc/config/turboacc
    }

    # Modify the cpu mode to schedutil
    [[ -f "${tmp_path}/etc/config/cpufreq" ]] && {
        echo -e "${INFO} Adjust cpufreq settings"
        sed -i "s/ondemand/schedutil/g" ${tmp_path}/etc/config/cpufreq
    }

    # Relink the kmod program
    [[ -f "${common_files}/sbin/kmod" ]] && (
        echo -e "${INFO} Adjust kmod settings."
        cp -f ${common_files}/sbin/kmod ${tmp_path}/sbin/kmod
        chmod +x ${tmp_path}/sbin/kmod
        kmod_list="depmod insmod lsmod modinfo modprobe rmmod"
        for ki in ${kmod_list}; do
            rm -f ${tmp_path}/sbin/${ki}
            ln -sf kmod ${tmp_path}/sbin/${ki}
        done
    )

    # Add version information to the banner
    [[ -f "${common_files}/etc/banner" ]] && {
        cp -f ${common_files}/etc/banner ${tmp_path}/etc/banner
        echo -e "${INFO} Adjust banner settings."
        echo " Board: docker | Production Date: $(date +%Y-%m-%d)" >>${tmp_path}/etc/banner
        echo "───────────────────────────────────────────────────────────────────────" >>${tmp_path}/etc/banner
    }
    # ==============================================================================
    # ⬇️【镜像级防护 1】：设置容器环境变量与禁用硬件看门狗/硬件重启 ⬇️
    # ==============================================================================
    echo -e "${INFO} Applying Docker-native container patches..."

    # 1. 告诉 procd 和系统当前运行于 Docker 环境
    mkdir -p ${tmp_path}/etc/profile.d
    echo "export container=docker" > ${tmp_path}/etc/profile.d/docker.sh

    # 2. 修改 /etc/inittab，取消 procd 在 shutdown/ctrlaltdel 时的硬件重启响应
    if [ -f "${tmp_path}/etc/inittab" ]; then
        sed -i 's|::ctrlaltdel:/sbin/reboot|#::ctrlaltdel:/sbin/reboot|g' ${tmp_path}/etc/inittab
        sed -i 's|::shutdown:/etc/init.d/rcS K shutdown|::shutdown:/bin/true|g' ${tmp_path}/etc/inittab
    fi

    # 3. 禁用 uci 中的 system 看门狗与硬件 reboot 逻辑
    if [ -f "${tmp_path}/etc/config/system" ]; then
        sed -i '/watchdog/d' ${tmp_path}/etc/config/system
        echo "    option watchdog '0'" >> ${tmp_path}/etc/config/system
    fi
    # ==============================================================================
    # ⬇️【核心根治】防止几分钟后宿主机看门狗超时硬重启 ⬇️
    # ==============================================================================
    echo -e "${INFO} Injecting preinit hook to mask host /dev/watchdog..."

    # 1. 创建 preinit 早期启动钩子：在 procd 初始化前，将看门狗节点重定向至 /dev/null
    mkdir -p ${tmp_path}/lib/preinit
    cat << 'EOF' > ${tmp_path}/lib/preinit/00_disable_watchdog.sh
#!/bin/sh
# 容器启动极早期：删除容器内的宿主机看门狗节点，并用空设备(/dev/null)替换
rm -f /dev/watchdog /dev/watchdog0
mknod /dev/watchdog c 1 3 2>/dev/null || true
mknod /dev/watchdog0 c 1 3 2>/dev/null || true
EOF
    chmod +x ${tmp_path}/lib/preinit/00_disable_watchdog.sh

    # 2. 彻底清除 uci system 配置中的 watchdog 选项
    if [ -f "${tmp_path}/etc/config/system" ]; then
        sed -i '/watchdog/d' ${tmp_path}/etc/config/system
    fi
    # ==============================================================================
    # ⬇️【镜像级防护 2】：拦截 ubus 和命令行重启，防止 procd 触发 Syscall ⬇️
    # ==============================================================================
    echo -e "${INFO} Overriding reboot/poweroff commands with safe container exit..."

    # 移除原有的二进制文件/链接
    rm -f ${tmp_path}/sbin/reboot ${tmp_path}/sbin/poweroff ${tmp_path}/sbin/halt

    # 写入安全版 reboot：优雅停止服务后强制退出容器进程，绝不让 procd 走向最后一步 Syscall
    cat << 'EOF' > ${tmp_path}/sbin/reboot
#!/bin/sh
echo "[Docker-OpenWrt] Safe rebooting container..."
sync
# 停止 OpenWrt 主要服务，但不触发 procd 的硬件关机流程
/etc/init.d/rcS K shutdown 2>/dev/null
# 强制终止所有容器内进程，让 Docker 捕获到容器退出并重新拉起 (--restart always)
kill -9 -1 2>/dev/null || kill -KILL 1
EOF

    cat << 'EOF' > ${tmp_path}/sbin/poweroff
#!/bin/sh
echo "[Docker-OpenWrt] Safe powering off container..."
sync
/etc/init.d/rcS K shutdown 2>/dev/null
kill -9 -1 2>/dev/null || kill -KILL 1
EOF

    ln -sf reboot ${tmp_path}/sbin/halt
    chmod +x ${tmp_path}/sbin/reboot ${tmp_path}/sbin/poweroff ${tmp_path}/sbin/halt
    # ==============================================================================
}

make_dockerimg() {
    cd ${tmp_path}
    echo -e "${STEPS} Start making docker image..."

    # Make docker image
    tar -czf ${docker_rootfs_file} *
    [[ "${?}" -eq "0" ]] || error_msg "Docker image creation failed."

    # Move the docker image to the output directory
    rm -rf ${out_path} && mkdir -p ${out_path}
    mv -f ${docker_rootfs_file} ${out_path}
    [[ "${?}" -eq "0" ]] || error_msg "Docker image move failed."
    echo -e "${INFO} Docker image packaging succeeded."

    cd ${current_path}

    # Add Dockerfile
    cp -f ${docker_path}/Dockerfile ${out_path}
    [[ "${?}" -eq "0" ]] || error_msg "Dockerfile addition failed."
    echo -e "${INFO} Dockerfile added successfully."

    # Remove temporary directory
    rm -rf ${tmp_path}

    sync && sleep 3
    echo -e "${INFO} Docker files list: \n$(ls -l ${out_path})"
    echo -e "${SUCCESS} Docker image successfully created."
}

# Show welcome message
echo -e "${STEPS} Welcome to the Docker Image Maker Tool."
echo -e "${INFO} Make path: [ ${PWD} ]"
#
check_depends
find_openwrt
adjust_settings
make_dockerimg
#
# All process completed
wait
