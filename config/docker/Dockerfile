FROM scratch
ADD openwrt-docker-armsr-armv8-default-rootfs.tar.gz /
# 把 ENV 放到 ENTRYPOINT 前面
ENV container=docker
EXPOSE 22 53 80 443 7681
ENTRYPOINT ["/sbin/init"]
