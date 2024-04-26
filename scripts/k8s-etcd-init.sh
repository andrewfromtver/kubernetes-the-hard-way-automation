#!/bin/sh

systemctl stop etcd

cp ${DISTR_SHARED_FOLDER_PATH}/etcd* /usr/local/bin/

mkdir -p /var/lib/etcd
chmod 700 /var/lib/etcd

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=${KEYS_SHARED_FOLDER_PATH}/kubernetes.pem \\
  --key-file=${KEYS_SHARED_FOLDER_PATH}/kubernetes-key.pem \\
  --peer-cert-file=${KEYS_SHARED_FOLDER_PATH}/kubernetes.pem \\
  --peer-key-file=${KEYS_SHARED_FOLDER_PATH}/kubernetes-key.pem \\
  --trusted-ca-file=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --peer-trusted-ca-file=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${ETCD_IP}:2380 \\
  --listen-peer-urls https://${ETCD_IP}:2380 \\
  --listen-client-urls https://${ETCD_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${ETCD_IP}:2379 \\
  --initial-cluster-token ${ETCD_TOKEN} \\
  --initial-cluster ${ETCD_NAME}=https://${ETCD_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=${SERVICE_RESTART_INTERVAL}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start etcd
systemctl enable etcd
