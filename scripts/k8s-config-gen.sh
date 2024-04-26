#!/bin/sh

cp ${DISTR_SHARED_FOLDER_PATH}/kubectl /usr/local/bin/

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
