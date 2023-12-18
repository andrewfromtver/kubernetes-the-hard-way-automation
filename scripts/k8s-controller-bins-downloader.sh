#!/bin/sh

# Prepare distr folder
mkdir -p ${DISTR_SHARED_FOLDER_PATH}

# Download k8s controller node bins
wget -q --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kubectl" \
  "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz"

# Make binaries executable and move to distr folder
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
mv kube-apiserver kube-controller-manager kube-scheduler kubectl helm-v${HELM_VERSION}-linux-amd64.tar.gz ${DISTR_SHARED_FOLDER_PATH}
