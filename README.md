# kubernetes-the-hard-way-automation
Inspired by the Kelsey Hightowers repository - kubernetes-the-hard-way

# how-to
* install `Vagrant`
* install vagrant reload plugin `vagrant plugin install vagrant-reload` for Hyper-V deployment
* install vagrant vmware desktop plugin `vagrant plugin install vagrant-vmware-desktop` for vmWare deployment
* add files `secrets.yaml` `resources.yaml` `network.yaml` `cert.yaml`
* execute `vagrant up` command from project root folder

# apps versions info
* `K8S_VERSION 1.28.0`
* `RUNC_VERSION 1.1.10`
* `CNI_VERSION 1.0.0`
* `CONTAINERD_VERSION 1.7.11`
* `ETCD_VERSION 3.5.11`
* `CFSSL_VERSION 1.6.4`
* `HELM_VERSION 3.13.3`

# screenshots
![k8s-dashboard](./docs/screenshots/dashboard.png)

![k8s-haproxy](./docs/screenshots/haproxy.png)

![k8s-vms](./docs/screenshots/hyper-v_vms.png)  
