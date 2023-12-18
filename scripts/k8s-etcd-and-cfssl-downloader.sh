#!/bin/sh

# Prepare distr folder
mkdir -p ${DISTR_SHARED_FOLDER_PATH}

# Download etcd
wget -q --https-only --timestamping \
  "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"

# Unpack and move to distr folder
tar -xvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
mv etcd-v${ETCD_VERSION}-linux-amd64/etcd* ${DISTR_SHARED_FOLDER_PATH}/

# Download and install cfssl cfssljson bins
wget -q --https-only --timestamping \
  https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64 \
  https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64

# Make executable and move to distr folder
chmod +x cfssl_${CFSSL_VERSION}_linux_amd64 cfssljson_${CFSSL_VERSION}_linux_amd64
mv cfssl_${CFSSL_VERSION}_linux_amd64 ${DISTR_SHARED_FOLDER_PATH}/cfssl
mv cfssljson_${CFSSL_VERSION}_linux_amd64 ${DISTR_SHARED_FOLDER_PATH}/cfssljson
