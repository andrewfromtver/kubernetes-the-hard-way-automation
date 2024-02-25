# encoding: utf-8
# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

current_dir = File.dirname(File.expand_path(__FILE__))
secrets = YAML.load_file("#{current_dir}/secrets.yaml")
resources = YAML.load_file("#{current_dir}/resources.yaml")
network = YAML.load_file("#{current_dir}/network.yaml")
cert = YAML.load_file("#{current_dir}/cert.yaml")

CLEAR_DEPLOYMENT = false                                                # do not use cashed distrs and old keys

PROVIDER = "hyperv"                                                     # vmware_desktop, virtualbox, hyperv
PROVIDER_GUI = false                                                    # show vms in provider gui
VM_BOX = "generic/debian12"                                             # vm OC
VM_BOX_VERSION = "4.3.2"                                                # vm OC box version

K8S_VERSION = "1.28.0"                                                  # k8s bin files version
RUNC_VERSION = "1.1.10"                                                 # runc version
CNI_VERSION = "1.0.0"                                                   # cni version
CONTAINERD_VERSION = "1.7.11"                                           # containerd version
ETCD_VERSION = "3.5.11"                                                 # etcd version
CFSSL_VERSION = "1.6.4"                                                 # cfssl version
HELM_VERSION = "3.13.3"                                                 # HELM version

SMB_USER = secrets["username"]                                          # SMB user for hyperv provider folder sync
SMB_PASSWORD = secrets["password"]                                      # SMB password for hyperv provider folder sync
HYPERV_SWITCH = secrets["switch_name"]                                  # Hyper-V switch name

CONTROLLER_CPU = resources["controller_cpu"]                            # CPU qty for controller
CONTROLLER_RAM = resources["controller_ram"]                            # RAM size for controller
WORKER_CPU = resources["worker_cpu"]                                    # CPU qty for worker
WORKER_RAM = resources["worker_ram"]                                    # RAM size for worker
HAPROXY_CPU = resources["haproxy_cpu"]                                  # CPU qty for HAPROXY
HAPROXY_RAM = resources["haproxy_ram"]                                  # RAM size for HAPROXY

GATEWAY_IP = network["gateway_ip"]                                      # Hyper-V gateway IP
NET_MASK = network["net_mask"]                                          # net mask for Hyper-V
NET_RANGE = network["net_range"]                                        # net range for Hyper-V
CONTROLLERS_IP_ARRAY = network["controllers_ip"]                        # 3 x controller + etcd nodes
WORKERS_IP_ARRAY = network["workers_ip"]                                # 2 x workers
HAPROXY_IP = network["haproxy_ip"]                                      # cluster load balanser ip
POD_CIDR = network["pod_cidr"]                                          # pod cidr
CLUSTER_CIDR = network["cluster_cidr"]                                  # cluster cidr
SERVICE_CLUSTER_IP_RANGE = network["service_cluster_ip_range"]          # cluster ip range
SERVICE_CLUSTER_DNS = network["service_cluster_dns"]                    # cluster dns ip
SERVICE_CLUSTER_GATEWAY = network["service_cluster_gateway"]            # cluster gateway ip

ENCRYPTION_KEY = secrets["k8s_encrypt_key"]                             # k8s encryption key
ETCD_TOKEN = secrets["etcd_token"]                                      # etcd token

EXPIRY = cert["expiry"]                                                 # cert expire time
ALGO = cert["algo"]                                                     # cert algo
SIZE = cert["sizr"]                                                     # cert size
C = cert["c"]                                                           # cetr country
L = cert["l"]                                                           # cert location
O = cert["o"]                                                           # cert org.
OU = cert["ou"]                                                         # cert org. unit
ST = cert["st"]                                                         # cert state

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
        v.name = "haproxy"
        v.gui = PROVIDER_GUI 
      end
      if PROVIDER == "hyperv"
        v.vmname = "haproxy"
        v.maxmemory = HAPROXY_RAM + 1024
      end
      if PROVIDER == "vmware_desktop"
        v.vmx["displayname"] = "haproxy"
        v.gui = PROVIDER_GUI
      end
      v.memory = HAPROXY_RAM
      v.cpus = HAPROXY_CPU
    end
    if PROVIDER == "hyperv"
      haproxy.trigger.before :up do |up_trigger|
        up_trigger.info = "Creating 'k8s-net' Hyper-V switch if it does not exist..."
        up_trigger.run = {
          privileged: "true", 
          powershell_elevated_interactive: "true", 
          path: "./scripts/powershell/create-nat-hyperv-switch.ps1",
          args: [HYPERV_SWITCH, GATEWAY_IP, NET_MASK, NET_RANGE]
        }
      end
      haproxy.trigger.before :reload do |reload_trigger|
        reload_trigger.info = "Setting Hyper-V switch to 'k8s-net' to allow for static IP..."
        reload_trigger.run = {
          privileged: "true", 
          powershell_elevated_interactive: "true", 
          path: "./scripts/powershell/set-hyperv-switch.ps1",
          args: ["haproxy", HYPERV_SWITCH]
        }
      end
      haproxy.vm.provision "shell", run: "once", path: "./scripts/k8s-hyperv-ip-fix.sh", privileged: true, env: {
        "GATEWAY_IP" => GATEWAY_IP,
        "CURRENT_IP" => HAPROXY_IP
      }
    else
      haproxy.vm.network "private_network", ip: HAPROXY_IP
    end
    haproxy.vm.provision "shell", run: "once", path: "./scripts/k8s-haproxy-init.sh", privileged: true, env: {
      "CONTROLLER_IP_1" => CONTROLLERS_IP_ARRAY[0],
      "CONTROLLER_IP_2" => CONTROLLERS_IP_ARRAY[1],
      "CONTROLLER_IP_3" => CONTROLLERS_IP_ARRAY[2],
      "WORKER_IP_1" => WORKERS_IP_ARRAY[0],
      "WORKER_IP_2" => WORKERS_IP_ARRAY[1]
    }
    if PROVIDER == "hyperv"
      haproxy.vm.provision :reload
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
          v.name = "worker-#{i}"
          v.gui = PROVIDER_GUI
        end
        if PROVIDER == "hyperv"
          v.vmname = "worker-#{i}"
          v.maxmemory = WORKER_RAM + 1024
        end
        if PROVIDER == "vmware_desktop"
          v.vmx["displayname"] = "worker-#{i}"
          v.gui = PROVIDER_GUI
        end
        v.memory = WORKER_RAM
        v.cpus = WORKER_CPU
      end
      worker.vm.hostname = "worker-#{i}"
      if PROVIDER == "hyperv"
        worker.vm.synced_folder "./shared", "/shared", type: "smb", mount_options: [
          "username=#{SMB_USER}", 
          "password=#{SMB_PASSWORD}"
        ], smb_password: SMB_PASSWORD, smb_username: SMB_USER
        worker.trigger.before :reload do |reload_trigger|
          reload_trigger.info = "Setting Hyper-V switch to 'k8s-net' to allow for static IP..."
          reload_trigger.run = {
            privileged: "true", 
            powershell_elevated_interactive: "true", 
            path: "./scripts/powershell/set-hyperv-switch.ps1",
            args: ["worker-#{i}", HYPERV_SWITCH]
          }
        end
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-hyperv-ip-fix.sh", privileged: true, env: {
          "GATEWAY_IP" => GATEWAY_IP,
          "CURRENT_IP" => WORKERS_IP_ARRAY[i - 1]
        }
      else
        worker.vm.network "private_network", ip: WORKERS_IP_ARRAY[i - 1]
        worker.vm.synced_folder "./shared", "/shared"
      end
      if (i == 1 && CLEAR_DEPLOYMENT == true) then
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-etcd-and-cfssl-downloader.sh", privileged: false, env: {
          "DISTR_SHARED_FOLDER_PATH" => "/shared/distr",
          "ETCD_VERSION" => ETCD_VERSION,
          "CFSSL_VERSION" => CFSSL_VERSION
        }
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-controller-bins-downloader.sh", privileged: false, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "K8S_VERSION" => K8S_VERSION,
          "HELM_VERSION" => HELM_VERSION
        }
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-worker-bins-downloader.sh", privileged: false, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "K8S_VERSION" => K8S_VERSION,
          "RUNC_VERSION" => RUNC_VERSION,
          "CNI_VERSION" => CNI_VERSION,
          "CONTAINERD_VERSION" => CONTAINERD_VERSION
        }
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-cert-gen.sh", privileged: true, env: {
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
          "CONTROLLER_1_IP" => CONTROLLERS_IP_ARRAY[0],
          "CONTROLLER_2_IP" => CONTROLLERS_IP_ARRAY[1],
          "CONTROLLER_3_IP" => CONTROLLERS_IP_ARRAY[2],
          "KUBERNETES_PUBLIC_ADDRESS" => HAPROXY_IP
        }
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-config-gen.sh", privileged: true, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
          "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
          "KUBERNETES_PUBLIC_ADDRESS" => HAPROXY_IP
        }
      end
      worker.vm.provision "shell", run: "once", path: "./scripts/k8s-worker-cert-config-gen.sh", privileged: true, env: {
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
      worker.vm.provision "shell", run: "once", path: "./scripts/k8s-worker-init.sh", privileged: true, env: {
        "WORKER_1_IP" => WORKERS_IP_ARRAY[0],
        "WORKER_2_IP" => WORKERS_IP_ARRAY[1],
        "WORKER_1_NAME" => "worker-1",
        "WORKER_2_NAME" => "worker-2",
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "POD_CIDR" => POD_CIDR,
        "CLUSTER_CIDR" => CLUSTER_CIDR,
        "SERVICE_CLUSTER_DNS" => SERVICE_CLUSTER_DNS,
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
        worker.vm.provision "shell", run: "always", privileged: true, inline: <<-SHELL
          systemctl stop containerd kubelet kube-proxy || \
            echo "Services containerd kubelet kube-proxy not started"
          swapoff -a
          mkdir -p /run/systemd/resolve
          echo "nameserver 8.8.8.8" > /etc/resolv.conf
          echo "nameserver 8.8.4.4" >> /etc/resolv.conf
          echo "search localdomain" >> /etc/resolv.conf
          ln -s /etc/resolv.conf /run/systemd/resolve/resolv.conf || echo "File resolv.conf already exists"
          mkdir /sys/fs/cgroup/systemd
          mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
          systemctl start containerd kubelet kube-proxy
          echo "Worker node init done"
        SHELL
      end
      if PROVIDER == "hyperv"
        worker.vm.provision :reload
      end
    end
  end
  # k8s controllers deploy
  $controller_nodes_count = CONTROLLERS_IP_ARRAY.length()
  (1..$controller_nodes_count).each do |i|
    config.vm.define "controller-#{i}" do |controller|
      controller.vm.box = VM_BOX
      controller.vm.box_version = VM_BOX_VERSION
      controller.vm.hostname = "controller-#{i}"
      controller.vm.provider PROVIDER do |v|
        if PROVIDER == "virtualbox"
          v.name = "controller-#{i}"
          v.gui = PROVIDER_GUI
        end
        if PROVIDER == "hyperv"
          v.vmname = "controller-#{i}"
          v.maxmemory = CONTROLLER_RAM + 1024
        end
        if PROVIDER == "vmware_desktop"
          v.vmx["displayname"] = "controller-#{i}"
          v.gui = PROVIDER_GUI
        end
        v.memory = CONTROLLER_RAM
        v.cpus = CONTROLLER_CPU
      end
      if PROVIDER == "hyperv"
        controller.vm.synced_folder "./shared", "/shared", type: "smb", mount_options: ["username=#{SMB_USER}","password=#{SMB_PASSWORD}"], smb_password: SMB_PASSWORD, smb_username: SMB_USER
        controller.vm.synced_folder "./addons", "/addons", type: "smb", mount_options: ["username=#{SMB_USER}","password=#{SMB_PASSWORD}"], smb_password: SMB_PASSWORD, smb_username: SMB_USER
        controller.trigger.before :reload do |reload_trigger|
          reload_trigger.info = "Setting Hyper-V switch to 'k8s-net' to allow for static IP..."
          reload_trigger.run = {
            privileged: "true", 
            powershell_elevated_interactive: "true", 
            path: "./scripts/powershell/set-hyperv-switch.ps1",
            args: ["controller-#{i}", HYPERV_SWITCH]
          }
        end
        controller.vm.provision "shell", run: "once", path: "./scripts/k8s-hyperv-ip-fix.sh", privileged: true, env: {
          "GATEWAY_IP" => GATEWAY_IP,
          "CURRENT_IP" => CONTROLLERS_IP_ARRAY[i - 1]
        }
      else
        controller.vm.network "private_network", ip: CONTROLLERS_IP_ARRAY[i - 1]
        controller.vm.synced_folder "./shared", "/shared"
        controller.vm.synced_folder "./addons", "/addons"
      end
      controller.vm.provision "shell", run: "once", path: "./scripts/k8s-etcd-init.sh", privileged: true, env: {
        "INTERNAL_IP" => CONTROLLERS_IP_ARRAY[i - 1],
        "ETCD_CURRENT_NAME" => "controller-#{i}",
        "ETCD_NAME_1" => "controller-1",
        "ETCD_NAME_2" => "controller-2",
        "ETCD_NAME_3" => "controller-3",
        "ETCD_IP_1" => CONTROLLERS_IP_ARRAY[0],
        "ETCD_IP_2" => CONTROLLERS_IP_ARRAY[1],
        "ETCD_IP_3" => CONTROLLERS_IP_ARRAY[2],
        "ETCD_TOKEN" => ETCD_TOKEN,
        "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
      }
      controller.vm.provision "shell", run: "once", path: "./scripts/k8s-controller-init.sh", privileged: true, env: {
        "WORKER_IP_1" => WORKERS_IP_ARRAY[0],
        "WORKER_IP_2" => WORKERS_IP_ARRAY[1],
        "WORKER_NAME_1" => "worker-1",
        "WORKER_NAME_2" => "worker-2",
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
        "ETCD_IP_1" => CONTROLLERS_IP_ARRAY[0],
        "ETCD_IP_2" => CONTROLLERS_IP_ARRAY[1],
        "ETCD_IP_3" => CONTROLLERS_IP_ARRAY[2],
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
      }
      if PROVIDER == "hyperv"
        controller.vm.provision :reload
      end
      if (i == $controller_nodes_count) then
        controller.vm.provision "shell", run: "once", path: "./scripts/k8s-api-server-setup.sh", privileged: true
        controller.vm.provision "shell", run: "once", privileged: false, inline: <<-SHELL
          # test etcd cluster
          ETCDCTL_API=3 etcdctl member list \
            --endpoints=https://127.0.0.1:2379 \
            --cacert=/shared/k8s_keys/ca.pem \
            --cert=/shared/k8s_keys/kubernetes.pem \
            --key=/shared/k8s_keys/kubernetes-key.pem
          # test local healthz
          curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz -s
          # test k8s cluster api
          kubectl cluster-info --kubeconfig /shared/k8s_configs/admin.kubeconfig
        SHELL
        controller.vm.provision "shell", run: "once", privileged: false, inline: <<-SHELL
          kubectl delete -f /addons --kubeconfig /shared/k8s_configs/admin.kubeconfig || \
            echo "No addons installed"
          kubectl apply -f /addons --kubeconfig /shared/k8s_configs/admin.kubeconfig
          sleep 5
          kubectl patch storageclass default -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' --kubeconfig /shared/k8s_configs/admin.kubeconfig
          kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} --kubeconfig /shared/k8s_configs/admin.kubeconfig | base64 -d
        SHELL
      end
      controller.trigger.after :up do
        controller.vm.provision "shell", run: "always", privileged: true, inline: <<-SHELL
          systemctl stop kube-apiserver kube-controller-manager kube-scheduler || \
            echo "Services kube-apiserver kube-controller-manager kube-scheduler not started"
          swapoff -a
          mkdir -p /run/systemd/resolve
          echo "nameserver 8.8.8.8" > /etc/resolv.conf
          echo "nameserver 8.8.4.4" >> /etc/resolv.conf
          echo "search localdomain" >> /etc/resolv.conf
          ln -s /etc/resolv.conf /run/systemd/resolve/resolv.conf || echo "File resolv.conf already exists"
          systemctl start kube-apiserver kube-controller-manager kube-scheduler
          echo "Controller node init done"
        SHELL
      end
    end
  end
end
