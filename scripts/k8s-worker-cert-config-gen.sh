#!/bin/sh

cp ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/
cp ${DISTR_SHARED_FOLDER_PATH}/cfssl* /usr/local/bin/

# The Kubelet Client Certificates
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

cat > ${HOST_NAME}-csr.json <<EOF
{
  "CN": "system:node:${HOST_NAME}",
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
  -hostname=${HOST_NAME},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${HOST_NAME}-csr.json | cfssljson -bare ${HOST_NAME}

mv ${HOST_NAME}.pem ${HOST_NAME}-key.pem ${KEYS_SHARED_FOLDER_PATH}

# The kubelet Kubernetes Configuration File
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=${HOST_NAME}.kubeconfig

kubectl config set-credentials system:node:${HOST_NAME} \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/${HOST_NAME}.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/${HOST_NAME}-key.pem \
  --embed-certs=true \
  --kubeconfig=${HOST_NAME}.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=system:node:${HOST_NAME} \
  --kubeconfig=${HOST_NAME}.kubeconfig

kubectl config use-context default --kubeconfig=${HOST_NAME}.kubeconfig

mv ${HOST_NAME}.kubeconfig ${CONFIGS_SHARED_FOLDER_PATH}
