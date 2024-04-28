#!/bin/sh

# copy common utils
cp ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/
cp ${DISTR_SHARED_FOLDER_PATH}/cfssl* /usr/local/bin/

# certificate authority
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

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "${O}",
      "OU": "CA",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# admin client certificate
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:masters",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

# controller manager client certificate
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:kube-controller-manager",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

# kube proxy client certificate
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:node-proxier",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

# scheduler client certificate
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "system:kube-scheduler",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

# kubernetes API server certificate
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "${O}",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${SERVICE_CLUSTER_GATEWAY},${CONTROLLER_IP},${GATEWAY_IP},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# service account key pair
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "${ALGO}",
    "size": ${SIZE}
  },
  "names": [
    {
      "C": "${C}",
      "L": "${L}",
      "O": "${O}",
      "OU": "${OU}",
      "ST": "${ST}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

# distribute certificates
mkdir -p $KEYS_SHARED_FOLDER_PATH
mv *.pem $KEYS_SHARED_FOLDER_PATH

# kube-proxy kubernetes config
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://${CONTROLLER_IP}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/kube-proxy.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# kube-controller-manager kubernetes config
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/kube-controller-manager.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# kube-scheduler kubernetes config
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/kube-scheduler.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# admin kubernetes config
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://${CONTROLLER_IP}:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/admin.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/admin-key.pem \
  --token="DASHBOARD_USER_TOKEN" \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

# distribute kubernetes configs
mkdir -p ${CONFIGS_SHARED_FOLDER_PATH}
mv *.kubeconfig ${CONFIGS_SHARED_FOLDER_PATH}
