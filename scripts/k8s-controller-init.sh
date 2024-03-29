#!/bin/sh

# Prepare node
systemctl stop kube-apiserver kube-controller-manager kube-scheduler nginx || \
  echo "Services kube-apiserver kube-controller-manager kube-scheduler nginx not started"
mkdir -p /run/systemd/resolve
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "search localdomain" >> /etc/resolv.conf
echo "127.0.0.1 localhost" > /etc/hosts
echo "${WORKER_IP_1} ${WORKER_NAME_1}" >> /etc/hosts
echo "${WORKER_IP_2} ${WORKER_NAME_2}" >> /etc/hosts
cp ${DISTR_SHARED_FOLDER_PATH}/kube-apiserver \
  ${DISTR_SHARED_FOLDER_PATH}/kube-controller-manager \
  ${DISTR_SHARED_FOLDER_PATH}/kube-scheduler \
  ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/
mkdir -p /etc/kubernetes/config
tar -zxvf ${DISTR_SHARED_FOLDER_PATH}/helm-v${HELM_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
helm version --short

# Set encryption
cat > /etc/kubernetes/config/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

# Configure kube apiserver
cat <<EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --runtime-config=api/all=true \
  --requestheader-allowed-names=aggregator \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-username-headers=X-Remote-User \
  --requestheader-extra-headers-prefix=X-Remote-Extra- \
  --requestheader-client-ca-file=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --proxy-client-cert-file=${KEYS_SHARED_FOLDER_PATH}/admin.pem \
  --proxy-client-key-file=${KEYS_SHARED_FOLDER_PATH}/admin-key.pem \
  --enable-aggregator-routing=true \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --etcd-certfile=${KEYS_SHARED_FOLDER_PATH}/kubernetes.pem \\
  --etcd-keyfile=${KEYS_SHARED_FOLDER_PATH}/kubernetes-key.pem \\
  --etcd-servers=https://${ETCD_IP_1}:2379,https://${ETCD_IP_2}:2379,https://${ETCD_IP_3}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/etc/kubernetes/config/encryption-config.yaml \\
  --kubelet-certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --kubelet-client-certificate=${KEYS_SHARED_FOLDER_PATH}/kubernetes.pem \\
  --kubelet-client-key=${KEYS_SHARED_FOLDER_PATH}/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=${KEYS_SHARED_FOLDER_PATH}/service-account.pem \\
  --service-account-signing-key-file=${KEYS_SHARED_FOLDER_PATH}/service-account-key.pem \\
  --service-account-issuer=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=${KEYS_SHARED_FOLDER_PATH}/kubernetes.pem \\
  --tls-private-key-file=${KEYS_SHARED_FOLDER_PATH}/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=${SERVICE_RESTART_INTERVAL}

[Install]
WantedBy=multi-user.target
EOF

# Configure kube controller manager
cat <<EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --allocate-node-cidrs=true \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --cluster-signing-key-file=${KEYS_SHARED_FOLDER_PATH}/ca-key.pem \\
  --kubeconfig=${CONFIGS_SHARED_FOLDER_PATH}/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=${KEYS_SHARED_FOLDER_PATH}/ca.pem \\
  --service-account-private-key-file=${KEYS_SHARED_FOLDER_PATH}/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=${SERVICE_RESTART_INTERVAL}

[Install]
WantedBy=multi-user.target
EOF

# Configure kube scheduler
cat <<EOF | tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "${CONFIGS_SHARED_FOLDER_PATH}/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

cat <<EOF | tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Start services
systemctl daemon-reload
systemctl enable kube-apiserver kube-controller-manager kube-scheduler
systemctl start kube-apiserver kube-controller-manager kube-scheduler

# Setup monitoring
apt-get update || echo "Not an apt manager"
apt-get install -y nginx curl

cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate ${KEYS_SHARED_FOLDER_PATH}/ca.pem;
  }
}
EOF

mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-enabled/

systemctl restart nginx
systemctl enable nginx
