#!/bin/sh

# Prepare node
systemctl stop containerd kubelet kube-proxy || \
  echo "Services containerd kubelet kube-proxy not started"
swapoff -a
mkdir -p /run/systemd/resolve
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf
echo "search localdomain" >> /etc/resolv.conf
echo "127.0.0.1 localhost" > /etc/hosts
echo "${WORKER_1_IP} ${WORKER_1_NAME}" >> /etc/hosts
echo "${WORKER_2_IP} ${WORKER_2_NAME}" >> /etc/hosts
echo "${WORKER_3_IP} ${WORKER_3_NAME}" >> /etc/hosts
ln -s /etc/resolv.conf /run/systemd/resolve/resolv.conf

mkdir /sys/fs/cgroup/systemd
mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
apt-get update
apt-get -y install socat conntrack ipset
mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
mkdir containerd
tar -xvf ${DISTR_SHARED_FOLDER_PATH}/crictl-v${K8S_VERSION}-linux-amd64.tar.gz
tar -xvf ${DISTR_SHARED_FOLDER_PATH}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C containerd
tar -xvf ${DISTR_SHARED_FOLDER_PATH}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz -C /opt/cni/bin/
cp ${DISTR_SHARED_FOLDER_PATH}/runc.amd64 runc
chmod +x crictl ${DISTR_SHARED_FOLDER_PATH}/kubectl ${DISTR_SHARED_FOLDER_PATH}/kube-proxy ${DISTR_SHARED_FOLDER_PATH}/kubelet runc 
mv crictl runc /usr/local/bin/
mv containerd/bin/* /bin/
cp ${DISTR_SHARED_FOLDER_PATH}/kubectl ${DISTR_SHARED_FOLDER_PATH}/kube-proxy ${DISTR_SHARED_FOLDER_PATH}/kubelet /usr/local/bin/

# Configure CNI Networking
cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "${CNI_VERSION}",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "${CNI_VERSION}",
    "name": "lo",
    "type": "loopback"
}
EOF

# Configure containerd
mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
EOF

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
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

# Configure the Kubelet
cp ${KEYS_SHARED_FOLDER_PATH}/${HOSTNAME}-key.pem ${KEYS_SHARED_FOLDER_PATH}/${HOSTNAME}.pem /var/lib/kubelet/
cp ${CONFIGS_SHARED_FOLDER_PATH}/${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
cp ${KEYS_SHARED_FOLDER_PATH}/ca.pem /var/lib/kubernetes/

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "${KEYS_SHARED_FOLDER_PATH}/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "${SERVICE_CLUSTER_DNS_IP}"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "${KEYS_SHARED_FOLDER_PATH}/${HOSTNAME}.pem"
tlsPrivateKeyFile: "${KEYS_SHARED_FOLDER_PATH}/${HOSTNAME}-key.pem"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --fail-swap-on=false \\
  --v=2
Restart=on-failure
RestartSec=${SERVICE_RESTART_INTERVAL}

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Proxy
cp ${CONFIGS_SHARED_FOLDER_PATH}/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${CLUSTER_CIDR}"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
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

# Start the Worker Services
systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy
