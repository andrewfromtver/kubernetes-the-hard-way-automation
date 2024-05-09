# Kubernetes-the-hard-way-automation

This project is inspired by Kelsey Hightower's repository - kubernetes-the-hard-way.

# How-to

* install `Vagrant`
* install vagrant reload plugin `vagrant plugin install vagrant-reload` for Hyper-V deployment
* install vagrant vmware desktop plugin `vagrant plugin install vagrant-vmware-desktop` for vmWare deployment
* add `secrets.yaml` file to root folder of the project
* execute `vagrant up` command from project root folder

# Values of secrets.yaml

* `username: "smb_username"`        # for Hyper-V deployment
* `password: "smb_password"`        # for Hyper-V deployment
* `k8s_encrypt_key: "strong_key"`   # 16 24 or 32 chars key
* `etcd_token: "strong_token"`

# Cluster management

To manage the cluster, update the YAML files:

* `network.yaml` to set nodes qty and IP
* `resources.yaml` to set controller/worker node CPU and RAM

# Deployed apps management

To manage deployed apps, update the YAML file:

* `addons.yaml` set true or false and execute `vagrant up` to apply changes to cluster

# Versions

* `K8S_VERSION 1.30.0`
* `RUNC_VERSION 1.1.12`
* `CNI_VERSION 1.0.0`
* `CONTAINERD_VERSION 1.7.15`
* `ETCD_VERSION 3.5.13`
* `CFSSL_VERSION 1.6.5`
* `HELM_VERSION 3.14.4`

# Screenshots

![all-pods-from-lens](./docs/screenshots/all-pods-from-lens.png)

![all-nodes-from-kubernetes-dashboard](./docs/screenshots/all-nodes-from-kubernetes-dashboard.png)  
