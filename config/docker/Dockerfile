FROM scratch
ADD openwrt-docker-armsr-armv8-default-rootfs.tar.gz /
ENV container=docker
EXPOSE 22 53 80 443 7681
# 👇 修改这里：将入口指向 entrypoint 脚本，而不是直接运行 /sbin/init
ENTRYPOINT ["/docker-entrypoint.sh"]
