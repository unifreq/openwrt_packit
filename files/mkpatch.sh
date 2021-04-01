#!/bin/bash

sed -e "s/net.nf_conntrack_max net.ipv4.netfilter.ip_conntrack_max/net.netfilter.nf_conntrack_max net.nf_conntrack_max net.ipv4.netfilter.ip_conntrack_max \| head -n 1/" -i index.htm
diff -uprN index.htm.orig index.htm > luci-admin-status-index-html.patch
