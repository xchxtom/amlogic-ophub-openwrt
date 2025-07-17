#!/bin/bash
#========================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Automatically Build OpenWrt
# Function: Diy script (Before Update feeds, Modify the default IP, hostname, theme, add/remove software packages, etc.)
# Source code repository: https://github.com/immortalwrt/immortalwrt / Branch: master
#========================================================================================================================

# Add a feed source
# sed -i '$a src-git lienol https://github.com/Lienol/openwrt-package' feeds.conf.default
# other
# rm -rf package/emortal/{autosamba,ipv6-helper}
sed -i '$a src-git istore https://github.com/linkease/istore;main' feeds.conf.default
sed -i '$a src-git linkease_nas https://github.com/linkease/nas-packages.git;master' feeds.conf.default
sed -i '$a src-git linkease_nas_luci https://github.com/linkease/nas-packages-luci.git;main' feeds.conf.default
#sed -i '$a src-git jjm2473_apps https://github.com/jjm2473/openwrt-apps.git;main' feeds.conf.default
