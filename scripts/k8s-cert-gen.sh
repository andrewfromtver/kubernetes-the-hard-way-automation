#!/bin/sh

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

# distribute client and server certificates
mkdir -p $KEYS_SHARED_FOLDER_PATH
mv *.pem $KEYS_SHARED_FOLDER_PATH
