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
    # ⬇️【纯镜像防护 1】：生成 Docker Entrypoint 入口拦截脚本 ⬇️
    # ==============================================================================
    echo -e "${INFO} Injecting custom /docker-entrypoint.sh..."
    cat << 'EOF' > ${tmp_path}/docker-entrypoint.sh
#!/bin/sh
# 1. 在 OpenWrt /sbin/init (procd) 运行前，抢先替换看门狗节点为 /dev/null (1, 3)
rm -f /dev/watchdog /dev/watchdog0 /dev/misc/watchdog
mknod /dev/watchdog c 1 3 2>/dev/null || true
mknod /dev/watchdog0 c 1 3 2>/dev/null || true

# 2. 尝试向物理看门狗发送 Magic Close 字符 'V' (防止宿主机处于历史残留倒计时)
echo -n "V" > /dev/watchdog 2>/dev/null || true

# 3. 屏蔽内核 panic 自动重启
sysctl -w kernel.panic=0 2>/dev/null || true

# 4. 将执行权交给 OpenWrt 原生的 /sbin/init
exec /sbin/init "$@"
EOF

    chmod +x ${tmp_path}/docker-entrypoint.sh

    # ==============================================================================
    # ⬇️【纯镜像防护 2】：彻底禁用 OpenWrt 配置文件中的看门狗逻辑 ⬇️
    # ==============================================================================
    echo -e "${INFO} Removing watchdog section from OpenWrt system config..."
    if [ -f "${tmp_path}/etc/config/system" ]; then
        # 删掉 config system 中的 watchdog 轮询配置
        sed -i '/watchdog/d' ${tmp_path}/etc/config/system
    fi
    rm -f ${tmp_path}/etc/init.d/watchdog 2>/dev/null || true

    # ==============================================================================
    # ⬇️【核心修复 3】：安全的 reboot/poweroff 重定向 ⬇️
    # ==============================================================================
    echo -e "${INFO} Overriding reboot/poweroff commands..."
    rm -f ${tmp_path}/sbin/reboot ${tmp_path}/sbin/poweroff ${tmp_path}/sbin/halt

    cat << 'EOF' > ${tmp_path}/sbin/reboot
#!/bin/sh
echo "[Docker-OpenWrt] Safe rebooting container..."
sync
/etc/init.d/rcS K shutdown 2>/dev/null
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
    # ⬇️【网络配置】：保持 br-lan 桥接，转换为 DHCP 客户端模式 ⬇️
    # ==============================================================================
    NET_FILE="${tmp_path}/etc/config/network"

    # 如果是无效软链接，强制删除以防写入报错
    if [ -L "${NET_FILE}" ] && [ ! -e "${NET_FILE}" ]; then
        echo -e "${WARN} Detected broken symlink at ${NET_FILE}, removing it..."
        rm -f "${NET_FILE}"
    fi

    if [ -f "${NET_FILE}" ]; then
        echo -e "${INFO} Modifying existing network config..."
        
        # 1. 将 lan 区域的 static 修改为 dhcp
        sed -i "/config interface 'lan'/,/config / s/option proto '.*/option proto 'dhcp'/" "${NET_FILE}"
        
        # 2. 清理所有静态 IP 字段（包含 list ipaddr 和 option ipaddr）
        sed -i "/config interface 'lan'/,/config / { 
            /list ipaddr/d
            /option ipaddr/d
            /option netmask/d
            /option gateway/d
            /option dns/d
            /option ip6assign/d
        }" "${NET_FILE}"
    else
        echo -e "${INFO} Creating new network config with br-lan in DHCP mode..."
        cat << 'EOF' > "${NET_FILE}"
config interface 'loopback'
	option device 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'

# 1. 显式声明 br-lan 桥接设备，将物理接口 eth0 加入桥接
config device
	option name 'br-lan'
	option type 'bridge'
	list ports 'eth0'

# 2. 将 lan 接口绑定到 br-lan 并启用 DHCP 客户端
config interface 'lan'
	option device 'br-lan'
	option proto 'dhcp'
EOF
    fi
    # 禁用 OpenWrt 自身的 DHCP 发牌服务（避免干扰上级主路由）
    if [ -f "${tmp_path}/etc/config/dhcp" ]; then
        echo -e "${INFO} Disabling container DHCP server..."
        sed -i "/config dhcp 'lan'/,/config / s/option ignore '.*/option ignore '1'/" ${tmp_path}/etc/config/dhcp
    fi
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
