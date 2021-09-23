#!/bin/bash
cd / && \
tar cvf /tmp/backup-${HOSTNAME}.tar.gz \
./etc/config/ \
./etc/crontabs/ \
./etc/dropbear/ \
./etc/easy-rsa/ \
./etc/luci-uploads/ \
./etc/nginx/ \
./etc/ocserv/ \
./etc/openvpn/ \
./etc/opkg/ \
./etc/php7/ \
./etc/php7-fpm.d/ \
./etc/samba/ \
./etc/strongswan.d/ \
./etc/gfwlist/ \
./etc/ipset/ \
./etc/dnsmasq.conf \
./etc/dnsmasq.ssr \
./etc/dnsmasq.oversea \
./etc/firewall.user \
./etc/group \
./etc/hosts \
./etc/inittab \
./etc/ssr_ip \
./etc/passwd \
./etc/profile \
./etc/shadow \
./etc/shells \
./etc/sysctl.conf \
./etc/sysctl.d \
./etc/xattr.conf \
./etc/bench.log \
./root/.ssh \
"./etc/rc.local" \
2>/dev/null
