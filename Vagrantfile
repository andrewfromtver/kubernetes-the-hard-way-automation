# encoding: utf-8
# -*- mode: ruby -*-
# vi: set ft=ruby :

PROVIDER = "virtualbox"                                                 # vmware_desktop or virtualbox
PROVIDER_GUI = false                                                    # show vms in provider gui
VM_BOX = "debian/bookworm64"                                            # vm OC
VM_BOX_VERSION = "12.20231211.1"                                        # vm OC box version

ETCD_CPU = 2                                                            # CPU qty for ETCD node
ETCD_RAM = 2048                                                         # RAM size for ETCD node
CONTROLLER_CPU = 2                                                      # CPU qty for CONTROLLER node
CONTROLLER_RAM = 2048                                                   # RAM size for CONTROLLER node
WORKER_CPU = 4                                                          # CPU qty for WORKER node
WORKER_RAM = 4096                                                       # RAM size for WORKER node
HAPROXY_CPU = 2                                                         # CPU qty for HAPROXY
HAPROXY_RAM = 2048                                                      # RAM size for HAPROXY

K8S_VERSION = "1.28.0"                                                  # k8s bin files version
RUNC_VERSION = "1.1.10"                                                 # runc version
CNI_VERSION = "1.4.0"                                                   # cni version
CONTAINERD_VERSION = "1.7.11"                                           # containerd version
ETCD_VERSION = "3.5.11"                                                 # etcd version
CFSSL_VERSION = "1.6.4"                                                 # cfssl version
HELM_VERSION = "3.13.3"                                                 # HELM version

CLEAR_DEPLOYMENT = false                                                # do not use cashed distrs and old keys

ENCRYPTION_KEY = "VP8yCfSinFYiZTMb7zujTI+qsUoTenzCV40Rm+4t7VA="         # k8s encryption key

ETCD_IP_ARRAY = ["192.168.56.10", "192.168.56.11", "192.168.56.12"]     # 3 nodes etcd cluster
CONTROLLERS_IP_ARRAY = ["192.168.56.13", "192.168.56.14"]               # 2 x controllers
WORKERS_IP_ARRAY = ["192.168.56.15", "192.168.56.16", "192.168.56.17"]  # 3 x workers
HAPROXY_IP = "192.168.56.100"                                           # cluster load balanser ip

POD_CIDR = "10.50.0.0/24"                                               # pod cidr
CLUSTER_CIDR = "10.100.0.0/16"                                          # cluster cidr
SERVICE_CLUSTER_IP_RANGE = "10.32.0.0/24"                               # cluster ip range
SERVICE_CLUSTER_DNS_IP = "10.32.0.10"                                   # cluster dns ip
SERVICE_CLUSTER_GATEWAY = "10.32.0.1"                                   # cluster gateway ip

EXPIRY = "8760h"                                                        # cert expity
ALGO = "rsa"                                                            # cert algo
SIZE = 2048                                                             # cert size
C = "US"                                                                # cetr country
L = "Portland"                                                          # cert location
O = "Kubernetes"                                                        # cert org.
OU = "k8s sefhosted cluster"                                            # cert org. unit
ST = "Oregon"                                                           # cert state

DISTR_SHARED_FOLDER_PATH = "/shared/distr"                              # distr folder
KEYS_SHARED_FOLDER_PATH = "/shared/k8s_keys"                            # keys folder
CONFIGS_SHARED_FOLDER_PATH = "/shared/k8s_configs"                      # configs folder

SERVICE_RESTART_INTERVAL = 5                                            # systemd service restart timer


Vagrant.configure(2) do |config|

  # haproxy
  config.vm.define "haproxy" do |haproxy|
    haproxy.vm.box = VM_BOX
    haproxy.vm.box_version = VM_BOX_VERSION
    haproxy.vm.hostname = "haproxy"
    haproxy.vm.provider PROVIDER do |v|
      if PROVIDER == "virtualbox"
        v.name = "ha proxy"
      end
      if PROVIDER == "vmware_desktop"
        v.vmx['displayname'] = "ha proxy"
      end
      v.memory = HAPROXY_RAM
      v.cpus = HAPROXY_CPU
    end
    haproxy.vm.network "private_network", ip: HAPROXY_IP
    haproxy.vm.provision "shell", run: 'once', path: "./scripts/k8s-haproxy-init.sh", privileged: true, env: {
      "ETCD_IP_1" => ETCD_IP_ARRAY[0],
      "ETCD_IP_2" => ETCD_IP_ARRAY[1],
      "ETCD_IP_3" => ETCD_IP_ARRAY[2],
      "CONTROLLER_NODE_1_IP" => CONTROLLERS_IP_ARRAY[0],
      "CONTROLLER_NODE_2_IP" => CONTROLLERS_IP_ARRAY[1],
      "WORKER_NODE_1_IP" => WORKERS_IP_ARRAY[0],
      "WORKER_NODE_2_IP" => WORKERS_IP_ARRAY[1],
      "WORKER_NODE_3_IP" => WORKERS_IP_ARRAY[2]
    }
  end

  # etcd cluster deploy
  $etcd_nodes_count = 3
  (1..$etcd_nodes_count).each do |i|
    config.vm.define "etcd-#{i}" do |node|
      node.vm.box = VM_BOX
      node.vm.box_version = VM_BOX_VERSION
      node.vm.provider PROVIDER do |v|
        if PROVIDER == "virtualbox"
          v.name = "etcd node #{i}"
        end
        if PROVIDER == "vmware_desktop"
          v.vmx['displayname'] = "etcd node #{i}"
        end
        v.memory = ETCD_RAM
        v.cpus = ETCD_CPU
        v.gui = PROVIDER_GUI
      end
      node.vm.hostname = "etcd-#{i}"
      node.vm.network "private_network", ip: ETCD_IP_ARRAY[i - 1]
      node.vm.synced_folder "./shared", "/shared"
      if (i == 1 && CLEAR_DEPLOYMENT == true)
        node.vm.provision "shell", run: 'once', path: "./scripts/k8s-etcd-and-cfssl-downloader.sh", privileged: false, env: {
          "DISTR_SHARED_FOLDER_PATH" => "/shared/distr",
          "ETCD_VERSION" => ETCD_VERSION,
          "CFSSL_VERSION" => CFSSL_VERSION
        }
        node.vm.provision "shell", run: 'once', path: "./scripts/k8s-cert-gen.sh", privileged: true, env: {
          "EXPIRY" => EXPIRY,
          "ALGO" => ALGO,
          "SIZE" => SIZE,
          "C" => C,
          "L" => L,
          "O" => O,
          "OU" => OU,
          "ST" => ST,
          "SERVICE_CLUSTER_GATEWAY" => SERVICE_CLUSTER_GATEWAY,
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
          "ETCD_IP_1" => ETCD_IP_ARRAY[0],
          "ETCD_IP_2" => ETCD_IP_ARRAY[1],
          "ETCD_IP_3" => ETCD_IP_ARRAY[2],
          "KUBERNETES_PUBLIC_ADDRESS" => HAPROXY_IP
        }
      end
      node.vm.provision "shell", run: 'once', path: "./scripts/k8s-etcd-init.sh", privileged: true, env: {
        "INTERNAL_IP" => ETCD_IP_ARRAY[i - 1],
        "ETCD_CURRENT_NAME" => "etcd-#{i}",
        "ETCD_NAME_1" => "etcd-1",
        "ETCD_NAME_2" => "etcd-2",
        "ETCD_NAME_3" => "etcd-3",
        "ETCD_IP_1" => ETCD_IP_ARRAY[0],
        "ETCD_IP_2" => ETCD_IP_ARRAY[1],
        "ETCD_IP_3" => ETCD_IP_ARRAY[2],
        "ETCD_TOKEN" => "etcd-cluster",
        "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
      }
      if (i == 3)
        node.vm.provision "shell", run: 'once', privileged: false, inline: <<-SHELL
          sleep 5
          ETCDCTL_API=3 etcdctl member list \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/shared/k8s_keys/ca.pem \
            --cert=/shared/k8s_keys/kubernetes.pem \
            --key=/shared/k8s_keys/kubernetes-key.pem
        SHELL
      end
    end
  end

  # k8s controllers deploy
  $controller_nodes_count = CONTROLLERS_IP_ARRAY.length()
  (1..$controller_nodes_count).each do |i|
    config.vm.define "controller-#{i}" do |controller|
      controller.vm.box = VM_BOX
      controller.vm.box_version = VM_BOX_VERSION
      controller.vm.provider PROVIDER do |v|
        if PROVIDER == "virtualbox"
          v.name = "controller node #{i}"
        end
        if PROVIDER == "vmware_desktop"
          v.vmx['displayname'] = "controller node #{i}"
        end
        v.memory = CONTROLLER_RAM
        v.cpus = CONTROLLER_CPU
        v.gui = PROVIDER_GUI
      end
      controller.vm.hostname = "controller-#{i}"
      controller.vm.network "private_network", ip: CONTROLLERS_IP_ARRAY[i - 1]
      controller.vm.synced_folder "./shared", "/shared"
      controller.vm.synced_folder "./addons", "/addons"
      if (i == 1 && CLEAR_DEPLOYMENT == true) then
        controller.vm.provision "shell", run: 'once', path: "./scripts/k8s-controller-bins-downloader.sh", privileged: false, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "K8S_VERSION" => K8S_VERSION,
          "HELM_VERSION" => HELM_VERSION
        }
        controller.vm.provision "shell", run: 'once', path: "./scripts/k8s-config-gen.sh", privileged: true, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
          "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
          "KUBERNETES_PUBLIC_ADDRESS" => HAPROXY_IP
        }
      end
      controller.vm.provision "shell", run: 'once', path: "./scripts/k8s-controller-init.sh", privileged: true, env: {
        "WORKER_1_IP" => WORKERS_IP_ARRAY[0],
        "WORKER_2_IP" => WORKERS_IP_ARRAY[1],
        "WORKER_3_IP" => WORKERS_IP_ARRAY[2],
        "WORKER_1_NAME" => "worker-1",
        "WORKER_2_NAME" => "worker-2",
        "WORKER_3_NAME" => "worker-3",
        "HELM_VERSION" => HELM_VERSION,
        "CNI_VERSION" => CNI_VERSION,
        "ENCRYPTION_KEY" => ENCRYPTION_KEY,
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "INTERNAL_IP" => CONTROLLERS_IP_ARRAY[i - 1],
        "KUBERNETES_PUBLIC_ADDRESS" => HAPROXY_IP,
        "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
        "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
        "SERVICE_CLUSTER_IP_RANGE" => SERVICE_CLUSTER_IP_RANGE,
        "CLUSTER_CIDR" => CLUSTER_CIDR,
        "ETCD_IP_1" => ETCD_IP_ARRAY[0],
        "ETCD_IP_2" => ETCD_IP_ARRAY[1],
        "ETCD_IP_3" => ETCD_IP_ARRAY[2],
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
      }
      controller.vm.provision "shell", run: 'once', privileged: false, inline: <<-SHELL
        echo 'export KUBECONFIG=/shared/k8s_configs/admin.kubeconfig' >> $HOME/.bashrc
        helm repo add bitnami https://charts.bitnami.com/bitnami
      SHELL
      if (i == $controller_nodes_count) then
        controller.vm.provision "shell", run: 'once', privileged: false, inline: <<-SHELL
          kubectl delete -f /addons --kubeconfig /shared/k8s_configs/admin.kubeconfig || \
            echo "No addons installed"
          kubectl apply -f /addons --kubeconfig /shared/k8s_configs/admin.kubeconfig
        SHELL
      end
      controller.trigger.after :up do
        controller.vm.provision "shell", run: 'always', privileged: true, inline: <<-SHELL
          swapoff -a
          mkdir -p /run/systemd/resolve
          echo "nameserver 8.8.8.8" > /etc/resolv.conf
          echo "nameserver 8.8.4.4" >> /etc/resolv.conf
          echo "search localdomain" >> /etc/resolv.conf
          echo "127.0.0.1 localhost" > /etc/hosts
          echo "#{WORKERS_IP_ARRAY[0]} worker-1" >> /etc/hosts
          echo "#{WORKERS_IP_ARRAY[1]} worker-2" >> /etc/hosts
          echo "#{WORKERS_IP_ARRAY[2]} worker-3" >> /etc/hosts
          ln -s /etc/resolv.conf /run/systemd/resolve/resolv.conf
          echo "Controller node resolve config done"      
        SHELL
      end
    end
  end

  # k8s workers deploy
  $worker_nodes_count = WORKERS_IP_ARRAY.length()
  (1..$worker_nodes_count).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.box = VM_BOX
      worker.vm.box_version = VM_BOX_VERSION
      worker.vm.provider PROVIDER do |v|
        if PROVIDER == "virtualbox"
          v.name = "worker node #{i}"
        end
        if PROVIDER == "vmware_desktop"
          v.vmx['displayname'] = "worker node #{i}"
        end
        v.memory = WORKER_RAM
        v.cpus = WORKER_CPU
        v.gui = PROVIDER_GUI
      end
      worker.vm.hostname = "worker-#{i}"
      worker.vm.network "private_network", ip: WORKERS_IP_ARRAY[i - 1]
      worker.vm.synced_folder "./shared", "/shared"
      if (i == 1 && CLEAR_DEPLOYMENT == true) then
        worker.vm.provision "shell", run: 'once', path: "./scripts/k8s-worker-bins-downloader.sh", privileged: false, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "K8S_VERSION" => K8S_VERSION,
          "RUNC_VERSION" => RUNC_VERSION,
          "CNI_VERSION" => CNI_VERSION,
          "CONTAINERD_VERSION" => CONTAINERD_VERSION
        }
      end
      worker.vm.provision "shell", run: 'once', path: "./scripts/k8s-worker-cert-config-gen.sh", privileged: true, env: {
        "EXPIRY" => EXPIRY,
        "ALGO" => ALGO,
        "SIZE" => SIZE,
        "C" => C,
        "L" => L,
        "OU" => OU,
        "ST" => ST,
        "HOST_NAME" => "worker-#{i}",
        "EXTERNAL_IP" => HAPROXY_IP,
        "INTERNAL_IP" => WORKERS_IP_ARRAY[i - 1],
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
        "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
        "KUBERNETES_PUBLIC_ADDRESS" => HAPROXY_IP
      }
      worker.vm.provision "shell", run: 'once', path: "./scripts/k8s-worker-init.sh", privileged: true, env: {
        "WORKER_1_IP" => WORKERS_IP_ARRAY[0],
        "WORKER_2_IP" => WORKERS_IP_ARRAY[1],
        "WORKER_3_IP" => WORKERS_IP_ARRAY[2],
        "WORKER_1_NAME" => "worker-1",
        "WORKER_2_NAME" => "worker-2",
        "WORKER_3_NAME" => "worker-3",
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "POD_CIDR" => POD_CIDR,
        "CLUSTER_CIDR" => CLUSTER_CIDR,
        "SERVICE_CLUSTER_DNS_IP" => SERVICE_CLUSTER_DNS_IP,
        "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
        "HOSTNAME" => "worker-#{i}",
        "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
        "K8S_VERSION" => K8S_VERSION,
        "RUNC_VERSION" => RUNC_VERSION,
        "CNI_VERSION" => CNI_VERSION,
        "CONTAINERD_VERSION" => CONTAINERD_VERSION,
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
      }
      worker.trigger.after :up do
        worker.vm.provision "shell", run: 'always', privileged: true, inline: <<-SHELL
          swapoff -a
          mkdir -p /run/systemd/resolve
          echo "nameserver 8.8.8.8" > /etc/resolv.conf
          echo "nameserver 8.8.4.4" >> /etc/resolv.conf
          echo "search localdomain" >> /etc/resolv.conf
          echo "127.0.0.1 localhost" > /etc/hosts
          echo "#{WORKERS_IP_ARRAY[0]} worker-1" >> /etc/hosts
          echo "#{WORKERS_IP_ARRAY[1]} worker-2" >> /etc/hosts
          echo "#{WORKERS_IP_ARRAY[2]} worker-3" >> /etc/hosts
          ln -s /etc/resolv.conf /run/systemd/resolve/resolv.conf
          echo "Worker node resolve config done"
        SHELL
      end
    end
  end

end
