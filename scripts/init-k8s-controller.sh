#!/bin/sh

# Prepare node
swapoff -a
echo "vm.swappiness = 1" >> /etc/sysctl.conf

systemctl stop kube-apiserver kube-controller-manager kube-scheduler etcd

cp ${DISTR_SHARED_FOLDER_PATH}/kube-apiserver \
  ${DISTR_SHARED_FOLDER_PATH}/kube-controller-manager \
  ${DISTR_SHARED_FOLDER_PATH}/kube-scheduler \
  ${DISTR_SHARED_FOLDER_PATH}/etcd* \
  ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/

# Copy keys and configs
KEYS_SHARED_FOLDER_LOCAL_PATH="/k8s/keys"
CONFIGS_SHARED_FOLDER_LOCAL_PATH="/k8s/configs"

mkdir -p $KEYS_SHARED_FOLDER_LOCAL_PATH
mkdir -p $CONFIGS_SHARED_FOLDER_LOCAL_PATH

rm -Rf $KEYS_SHARED_FOLDER_LOCAL_PATH/*
rm -Rf $CONFIGS_SHARED_FOLDER_LOCAL_PATH/*

cp $KEYS_SHARED_FOLDER_PATH/* $KEYS_SHARED_FOLDER_LOCAL_PATH
cp $CONFIGS_SHARED_FOLDER_PATH/* $CONFIGS_SHARED_FOLDER_LOCAL_PATH

tar -zxvf ${DISTR_SHARED_FOLDER_PATH}/helm-v${HELM_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
helm version --short

# Configure etcd
mkdir -p /var/lib/etcd
chmod 700 /var/lib/etcd
mkdir -p /etc/kubernetes/config

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes.pem \\
  --key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes-key.pem \\
  --peer-cert-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes.pem \\
  --peer-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes-key.pem \\
  --trusted-ca-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --peer-trusted-ca-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
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

BASE_64_ENCRYPTION_KEY=$(echo -n "$ENCRYPTION_KEY" | base64)

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
              secret: ${BASE_64_ENCRYPTION_KEY}
      - identity: {}
EOF

# Configure kube apiserver
cat <<EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --runtime-config=api/all=true \\
  --requestheader-allowed-names=aggregator \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --requestheader-extra-headers-prefix=X-Remote-Extra- \\
  --requestheader-client-ca-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --proxy-client-cert-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/admin.pem \\
  --proxy-client-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/admin-key.pem \\
  --enable-aggregator-routing=true \\
  --advertise-address=${CONTROLLER_IP} \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --etcd-certfile=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes.pem \\
  --etcd-keyfile=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes-key.pem \\
  --etcd-servers=https://${ETCD_IP}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/etc/kubernetes/config/encryption-config.yaml \\
  --kubelet-certificate-authority=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --kubelet-client-certificate=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes.pem \\
  --kubelet-client-key=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/service-account.pem \\
  --service-account-signing-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/service-account-key.pem \\
  --service-account-issuer=https://${CONTROLLER_IP}:6443 \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes.pem \\
  --tls-private-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/kubernetes-key.pem \\
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
  --cluster-signing-cert-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --cluster-signing-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca-key.pem \\
  --kubeconfig=${CONFIGS_SHARED_FOLDER_LOCAL_PATH}/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem \\
  --service-account-private-key-file=${KEYS_SHARED_FOLDER_LOCAL_PATH}/service-account-key.pem \\
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
  kubeconfig: "${CONFIGS_SHARED_FOLDER_LOCAL_PATH}/kube-scheduler.kubeconfig"
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
systemctl start kube-apiserver kube-controller-manager kube-scheduler etcd
systemctl enable kube-apiserver kube-controller-manager kube-scheduler etcd

# postinit delay
sleep $SERVICE_RESTART_INTERVAL

# configure admin kubeconfig
cat <<EOF | kubectl apply --kubeconfig ${CONFIGS_SHARED_FOLDER_LOCAL_PATH}/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig ${CONFIGS_SHARED_FOLDER_LOCAL_PATH}/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
