#!/bin/sh

# copy common utils
cp ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/
cp ${DISTR_SHARED_FOLDER_PATH}/cfssl* /usr/local/bin/

# kubelet client certificates
cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "${EXPIRY}"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "${EXPIRY}"
      }
    }
  }
}
EOF

cat > ${HOSTNAME}-csr.json <<EOF
{
  "CN": "system:node:${HOSTNAME}",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:nodes",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  -ca-key=${KEYS_SHARED_FOLDER_PATH}/ca-key.pem \
  -config=ca-config.json \
  -hostname=${HOSTNAME},${GATEWAY_IP},${CONTROLLER_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${HOSTNAME}-csr.json | cfssljson -bare ${HOSTNAME}

# distribute kubernetes certificates
mv ${HOSTNAME}.pem ${HOSTNAME}-key.pem ${KEYS_SHARED_FOLDER_PATH}

# kubelet kubernetes config
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://${CONTROLLER_IP}:6443 \
  --kubeconfig=${HOSTNAME}.kubeconfig

kubectl config set-credentials system:node:${HOSTNAME} \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/${HOSTNAME}.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/${HOSTNAME}-key.pem \
  --embed-certs=true \
  --kubeconfig=${HOSTNAME}.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=system:node:${HOSTNAME} \
  --kubeconfig=${HOSTNAME}.kubeconfig

kubectl config use-context default --kubeconfig=${HOSTNAME}.kubeconfig

# distribute kubernetes configs
mkdir -p ${CONFIGS_SHARED_FOLDER_PATH}
mv ${HOSTNAME}.kubeconfig ${CONFIGS_SHARED_FOLDER_PATH}/${HOSTNAME}.kubeconfig

# prepare node
modprobe br_netfilter
echo "br_netfilter" >> /etc/modules
echo "vm.swappiness = 1" >> /etc/sysctl.conf
echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
sysctl -p

systemctl stop containerd kubelet kube-proxy mount-systemd-cgroup

cat <<EOF | tee /etc/systemd/system/mount-systemd-cgroup.service
[Unit]
Description=Mount systemd cgroup
After=local-fs.target

[Service]
Type=oneshot
ExecStartPre=/bin/mkdir -p /sys/fs/cgroup/systemd
ExecStart=/bin/mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd

[Install]
WantedBy=multi-user.target
EOF

# Copy keys and configs
KEYS_SHARED_FOLDER_LOCAL_PATH="/k8s/keys"
CONFIGS_SHARED_FOLDER_LOCAL_PATH="/k8s/configs"

mkdir -p $KEYS_SHARED_FOLDER_LOCAL_PATH
mkdir -p $CONFIGS_SHARED_FOLDER_LOCAL_PATH

rm -Rf $KEYS_SHARED_FOLDER_LOCAL_PATH/*
rm -Rf $CONFIGS_SHARED_FOLDER_LOCAL_PATH/*

cp $KEYS_SHARED_FOLDER_PATH/* $KEYS_SHARED_FOLDER_LOCAL_PATH
cp $CONFIGS_SHARED_FOLDER_PATH/* $CONFIGS_SHARED_FOLDER_LOCAL_PATH

dpkg -i $DISTR_SHARED_FOLDER_PATH/apt_packages/k8s/*.deb

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /mnt/data/ \
  containerd
chmod 777 /mnt/data/
tar -xvf ${DISTR_SHARED_FOLDER_PATH}/crictl-v${K8S_VERSION}-linux-amd64.tar.gz
tar -xvf ${DISTR_SHARED_FOLDER_PATH}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C containerd
tar -xvf ${DISTR_SHARED_FOLDER_PATH}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz -C /opt/cni/bin/
cp ${DISTR_SHARED_FOLDER_PATH}/runc.amd64 runc
chmod +x crictl ${DISTR_SHARED_FOLDER_PATH}/kubectl ${DISTR_SHARED_FOLDER_PATH}/kube-proxy ${DISTR_SHARED_FOLDER_PATH}/kubelet runc 
mv crictl runc /usr/local/bin/
mv containerd/bin/* /bin/
cp ${DISTR_SHARED_FOLDER_PATH}/kubectl ${DISTR_SHARED_FOLDER_PATH}/kube-proxy ${DISTR_SHARED_FOLDER_PATH}/kubelet /usr/local/bin/

# configure CNI networking
cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
	"cniVersion": "${CNI_VERSION}",
	"name": "net",
	"type": "bridge",
	"bridge": "cni0",
	"isGateway": true,
	"ipMasq": true,
	"ipam": {
		"type": "host-local",
		"subnet": "${POD_CIDR}",
		"routes": [
			{ "dst": "0.0.0.0/0" }
		]
	}
}
EOF

cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "${CNI_VERSION}",
    "name": "lo",
    "type": "loopback"
}
EOF

# configure containerd
mkdir -p /etc/containerd/

cat << EOF | tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=${SERVICE_RESTART_INTERVAL}
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

# configure Kubelet
cp ${KEYS_SHARED_FOLDER_LOCAL_PATH}/${HOSTNAME}-key.pem ${KEYS_SHARED_FOLDER_LOCAL_PATH}/${HOSTNAME}.pem /var/lib/kubelet/
cp ${CONFIGS_SHARED_FOLDER_LOCAL_PATH}/${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
cp ${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem /var/lib/kubernetes/

cat <<EOF | tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "${KEYS_SHARED_FOLDER_LOCAL_PATH}/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "${SERVICE_CLUSTER_DNS}"
podCIDR: "${POD_CIDR}"
resolvConf: "/etc/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "${KEYS_SHARED_FOLDER_LOCAL_PATH}/${HOSTNAME}.pem"
tlsPrivateKeyFile: "${KEYS_SHARED_FOLDER_LOCAL_PATH}/${HOSTNAME}-key.pem"
EOF

cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --authentication-token-webhook=true \\
  --authorization-mode=Webhook \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --fail-swap-on=false \\
  --node-ip=${NODE_IP} \\
  --v=2
Restart=on-failure
RestartSec=${SERVICE_RESTART_INTERVAL}

[Install]
WantedBy=multi-user.target
EOF

# configure kube-proxy
cp ${CONFIGS_SHARED_FOLDER_LOCAL_PATH}/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${CLUSTER_CIDR}"
EOF

cat <<EOF | tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=${SERVICE_RESTART_INTERVAL}

[Install]
WantedBy=multi-user.target
EOF

# start node services
systemctl daemon-reload
systemctl start containerd kubelet kube-proxy mount-systemd-cgroup
systemctl enable containerd kubelet kube-proxy mount-systemd-cgroup
