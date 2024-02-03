#!/bin/sh

cat > /etc/network/interfaces <<EOF
auto eth0
iface eth0 inet static
address ${CURRENT_IP}
netmask 24
gateway ${GATEWAY_IP}
EOF
