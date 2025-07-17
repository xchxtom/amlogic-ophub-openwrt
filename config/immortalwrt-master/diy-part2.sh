#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (After Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: master
#========================================================================================================================

# ------------------------------- Main source started -------------------------------
#
# Add the default password for the 'root' user（Change the empty password to 'password'）
sed -i 's/root:::0:99999:7:::/root:$1$V4UetPzk$CYXluq4wUazHjmCDBCqXF.::0:99999:7:::/g' package/base-files/files/etc/shadow

# Set etc/openwrt_release
sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R$(date +%Y.%m.%d)'|g" package/base-files/files/etc/openwrt_release
echo "DISTRIB_SOURCECODE='immortalwrt'" >>package/base-files/files/etc/openwrt_release

# Modify default IP（FROM 192.168.1.1 CHANGE TO 192.168.31.4）
# sed -i 's/192.168.1.1/192.168.31.4/g' package/base-files/files/bin/config_generate
#
# ------------------------------- Main source ends -------------------------------

# ------------------------------- Other started -------------------------------
#
wget -P feeds/packages/multimedia/minidlna/patches/ https://raw.githubusercontent.com/stock169/openwrt-ipq40xx-generic-p2w_r619ac-128m/main/002-support-ape-mka-format.patch
#rm -f feeds/packages/sound/mpd/Makefile
#wget -P feeds/packages/sound/mpd/ https://raw.githubusercontent.com/stock169/amlogic-s9xxx-openwrt/main/Makefile
rm -f feeds/packages/lang/golang/golang/Makefile
wget -P feeds/packages/lang/golang/golang/ https://raw.githubusercontent.com/sbwml/packages_lang_golang/refs/heads/24.x/golang/Makefile
rm -f feeds/packages/utils/podman/Makefile
wget -P feeds/packages/utils/podman/ https://raw.githubusercontent.com/stock169/openwrt-ipq40xx-generic-p2w_r619ac-128m/refs/heads/main/Makefile
#rm -f target/linux/armsr/modules.mk
#wget -P target/linux/armsr/ https://raw.githubusercontent.com/openwrt/openwrt/refs/heads/main/target/linux/armsr/modules.mk
sed -i 's/USER="mpd"/USER="root"/g' feeds/packages/sound/mpd/files/mpd.init
sed -i 's/GROUP="mpd"/GROUP="root"/g' feeds/packages/sound/mpd/files/mpd.init
sed -i 's/mkdir \$(PKG_BUILD_DIR)\/\$(ARCH)/mkdir -p \$(PKG_BUILD_DIR)\/\$(ARCH)/g' feeds/packages/utils/coremark/Makefile
rm -rf feeds/luci/applications/luci-app-passwall
git clone https://github.com/xiaorouji/openwrt-passwall.git feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall/.git
rm -rf feeds/luci/applications/luci-app-passwall/.github
mv feeds/luci/applications/luci-app-passwall/luci-app-passwall/* feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall/luci-app-passwall
rm -rf feeds/packages/net/ipt2socks
rm -rf feeds/packages/net/pdnsd-alt
rm -rf feeds/packages/net/simple-obfs
rm -rf feeds/packages/net/tcping
rm -rf feeds/packages/net/trojan-plus
rm -rf feeds/packages/net/v2ray-geodata
rm -rf feeds/packages/net/xray-plugin
rm -rf feeds/packages/net/chinadns-ng
rm -rf feeds/packages/net/microsocks
rm -rf feeds/packages/net/shadowsocks-rust
rm -rf feeds/packages/net/sing-box
rm -rf feeds/packages/net/trojan
rm -rf feeds/packages/net/tuic-client
rm -rf feeds/packages/net/v2ray-plugin
rm -rf feeds/packages/net/dns2socks
rm -rf feeds/packages/net/hysteria
rm -rf feeds/packages/net/naiveproxy
rm -rf feeds/packages/net/shadowsocksr-libev
rm -rf feeds/packages/net/ssocks
rm -rf feeds/packages/net/trojan-go
rm -rf feeds/packages/net/v2ray-core
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/brook
rm -rf feeds/packages/net/dns2tcp
rm -rf feeds/packages/net/geoview
git clone https://github.com/xiaorouji/openwrt-passwall-packages.git feeds/packages/net/tmp
rm -rf feeds/packages/net/tmp/.git
rm -rf feeds/packages/net/tmp/.github
rm -rf feeds/packages/net/tmp/gn
mv feeds/packages/net/tmp/* feeds/packages/net
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
# Add luci-app-amlogic
rm -rf package/luci-app-amlogic
git clone https://github.com/ophub/luci-app-amlogic.git package/luci-app-amlogic
#git clone https://github.com/linkease/nas-packages.git package/luci/luci-app-quickstart
#git clone https://github.com/linkease/nas-packages-luci.git package/network/services/quickstart
#修改软件源
sed -i 's|https://downloads.openwrt.org/releases/SNAPSHOT|https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2|g' package/base-files/files/etc/opkg/distfeeds.conf
sed -i '$a src/gz immortalwrt_core https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2/targets/armsr/armv8/packages' package/base-files/files/etc/opkg/customfeeds.conf
sed -i '$a src/gz immortalwrt_base https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2/packages/aarch64_generic/base package/base-files/files/etc/opkg/customfeeds.conf
sed -i '$a src/gz immortalwrt_luci https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2/packages/aarch64_generic/luci package/base-files/files/etc/opkg/customfeeds.conf
sed -i '$a src/gz immortalwrt_packages https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2/packages/aarch64_generic/packages package/base-files/files/etc/opkg/customfeeds.conf
sed -i '$a src/gz immortalwrt_routing https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2/packages/aarch64_generic/routing package/base-files/files/etc/opkg/customfeeds.conf
sed -i '$a src/gz immortalwrt_telephony https://mirrors.cernet.edu.cn/openwrt/releases/24.10.2/packages/aarch64_generic/telephony package/base-files/files/etc/opkg/customfeeds.conf
# 修改主题
sed -i 's|option mediaurlbase .*|option mediaurlbase '/luci-static/argon'|g' package/base-files/files/etc/config/luci
#
# Apply patch
# git apply ../config/patches/{0001*,0002*}.patch --directory=feeds/luci
#
# ------------------------------- Other ends -------------------------------
