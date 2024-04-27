#!/bin/sh

cat > /etc/network/interfaces <<EOF
auto eth0
iface eth0 inet static
address ${CURRENT_IP}
netmask ${NET_RANGE}
gateway ${GATEWAY_IP}
EOF
