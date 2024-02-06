#!/bin/sh

cp ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/

# The kube-proxy Kubernetes Configuration File
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
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

# The kube-controller-manager Kubernetes Configuration File
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

# The kube-scheduler Kubernetes Configuration File
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

# The admin Kubernetes Configuration File
kubectl config set-cluster k8s-selfhosted-cluster \
  --certificate-authority=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=${KEYS_SHARED_FOLDER_PATH}/admin.pem \
  --client-key=${KEYS_SHARED_FOLDER_PATH}/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=k8s-selfhosted-cluster \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

# Distribute the Kubernetes Configuration Files
mkdir -p ${CONFIGS_SHARED_FOLDER_PATH}
mv *.kubeconfig ${CONFIGS_SHARED_FOLDER_PATH}
