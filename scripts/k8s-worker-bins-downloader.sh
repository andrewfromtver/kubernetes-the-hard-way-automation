#!/bin/sh

# prepare distr folder
mkdir -p ${DISTR_SHARED_FOLDER_PATH}

# download k8s worker node bins
wget -q --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v${K8S_VERSION}/crictl-v${K8S_VERSION}-linux-amd64.tar.gz \
  https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz \
  https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kubelet

# distribute
mv kube-proxy \
  kubelet \
  containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz \
  cni-plugins-linux-amd64-v${CNI_VERSION}.tgz \
  runc.amd64 crictl-v${K8S_VERSION}-linux-amd64.tar.gz \
  ${DISTR_SHARED_FOLDER_PATH}
