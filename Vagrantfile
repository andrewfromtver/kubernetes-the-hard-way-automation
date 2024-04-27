# encoding: utf-8
# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

current_dir = File.dirname(File.expand_path(__FILE__))
secrets = YAML.load_file("#{current_dir}/secrets.yaml")
resources = YAML.load_file("#{current_dir}/resources.yaml")
network = YAML.load_file("#{current_dir}/network.yaml")
cert = YAML.load_file("#{current_dir}/cert.yaml")

DOWNLOAD_BINS = false                                           # download k8s and common bins while deploying cluster, first init should be done with [true]

PROVIDER = "virtualbox"                                         # vmware_desktop, virtualbox, hyperv
PROVIDER_GUI = false                                            # show vms in provider gui
VM_BOX = "generic/debian12"                                     # vm OC
VM_BOX_VERSION = "4.3.2"                                        # vm OC box version

K8S_VERSION = "1.30.0"                                          # k8s bin files version
RUNC_VERSION = "1.1.12"                                         # runc version
CNI_VERSION = "1.0.0"                                           # cni version
CONTAINERD_VERSION = "1.7.15"                                   # containerd version
ETCD_VERSION = "3.5.13"                                         # etcd version
CFSSL_VERSION = "1.6.5"                                         # cfssl version
HELM_VERSION = "3.14.4"                                         # HELM version

SMB_USER = secrets["username"]                                  # SMB user for hyperv provider folder sync
SMB_PASSWORD = secrets["password"]                              # SMB password for hyperv provider folder sync
HYPERV_SWITCH = "k8s-net"                                       # Hyper-V switch name

CONTROLLER_CPU = resources["controller_cpu"]                    # CPU qty for controller
CONTROLLER_RAM = resources["controller_ram"]                    # RAM size for controller
WORKER_CPU = resources["worker_cpu"]                            # CPU qty for worker
WORKER_RAM = resources["worker_ram"]                            # RAM size for worker

GATEWAY_IP = network["gateway_ip"]                              # Hyper-V gateway IP
NET_MASK = network["net_mask"]                                  # net mask for Hyper-V
NET_RANGE = network["net_range"]                                # net range for Hyper-V
CONTROLLER_IP = network["controller_ip"]                        # controller + etcd node
WORKER_IPS_ARRAY = network["worker_ips"]                        # worker nodes [can be scaled]
POD_CIDR_ARRAY = network["pod_cidrs"]                           # pod cidr array
CLUSTER_CIDR = network["cluster_cidr"]                          # cluster cidr
SERVICE_CLUSTER_IP_RANGE = network["service_cluster_ip_range"]  # cluster ip range
SERVICE_CLUSTER_DNS = network["service_cluster_dns"]            # cluster dns ip
SERVICE_CLUSTER_GATEWAY = network["service_cluster_gateway"]    # cluster gateway ip

ENCRYPTION_KEY = secrets["k8s_encrypt_key"]                     # k8s encryption key
ETCD_TOKEN = secrets["etcd_token"]                              # etcd token
DASHBOARD_USER_TOKEN = secrets["dashboard_token"]               # kubernetes dashboard access token

EXPIRY = cert["expiry"]                                         # cert expire time
ALGO = cert["algo"]                                             # cert algo
SIZE = cert["size"]                                             # cert size
C = cert["c"]                                                   # cetr country
L = cert["l"]                                                   # cert location
O = cert["o"]                                                   # cert org.
OU = cert["ou"]                                                 # cert org. unit
ST = cert["st"]                                                 # cert state

DISTR_SHARED_FOLDER_PATH = "/shared/distr"                      # distr folder
KEYS_SHARED_FOLDER_PATH = "/shared/k8s_keys"                    # keys folder
CONFIGS_SHARED_FOLDER_PATH = "/shared/k8s_configs"              # configs folder

SERVICE_RESTART_INTERVAL = 5                                    # systemd service restart timer

Vagrant.configure(2) do |config|
  # k8s workers deploy
  $worker_nodes_count = WORKER_IPS_ARRAY.length()
  (1..$worker_nodes_count).each do |i|
    config.vm.define "worker-#{i}" do |worker|
      worker.vm.box = VM_BOX
      worker.vm.box_version = VM_BOX_VERSION
      worker.vm.provider PROVIDER do |v|
        v.memory = WORKER_RAM
        v.cpus = WORKER_CPU
        case PROVIDER
          when "virtualbox"
            v.name = "worker-#{i}"
            v.gui = PROVIDER_GUI
          when "hyperv"
            v.vmname = "worker-#{i}"
            v.maxmemory = WORKER_RAM + 1024
          when "vmware_desktop"
            v.vmx["displayname"] = "worker-#{i}"
            v.gui = PROVIDER_GUI
        end
      end
      worker.vm.hostname = "worker-#{i}"
      if PROVIDER == "hyperv"
        worker.vm.synced_folder "./shared", "/shared", type: "smb", mount_options: [
          "username=#{SMB_USER}", 
          "password=#{SMB_PASSWORD}"
        ], smb_password: SMB_PASSWORD, smb_username: SMB_USER
        if (i == 1) then
          worker.trigger.before :up do |up_trigger|
            up_trigger.info = "Creating 'k8s-net' Hyper-V switch if it does not exist..."
            up_trigger.run = {
              privileged: "true", 
              powershell_elevated_interactive: "true", 
              path: "./scripts/powershell/create-nat-hyperv-switch.ps1",
              args: [HYPERV_SWITCH, GATEWAY_IP, NET_MASK, NET_RANGE]
            }
          end
        end
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
          "NET_RANGE" => NET_RANGE,
          "CURRENT_IP" => WORKER_IPS_ARRAY[i - 1]
        }
      else
        worker.vm.network "private_network", ip: WORKER_IPS_ARRAY[i - 1]
        worker.vm.synced_folder "./shared", "/shared"
      end
      if (i == 1) then
        if (DOWNLOAD_BINS == true) then
          worker.vm.provision "shell", run: "once", path: "./scripts/download-etcd-and-cfssl.sh", privileged: false, env: {
            "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
            "ETCD_VERSION" => ETCD_VERSION,
            "CFSSL_VERSION" => CFSSL_VERSION
          }
          worker.vm.provision "shell", run: "once", path: "./scripts/download-k8s-controller-bins.sh", privileged: false, env: {
            "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
            "K8S_VERSION" => K8S_VERSION,
            "HELM_VERSION" => HELM_VERSION
          }
          worker.vm.provision "shell", run: "once", path: "./scripts/download-k8s-worker-bins.sh", privileged: false, env: {
            "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
            "K8S_VERSION" => K8S_VERSION,
            "RUNC_VERSION" => RUNC_VERSION,
            "CNI_VERSION" => CNI_VERSION,
            "CONTAINERD_VERSION" => CONTAINERD_VERSION
          }
        end
        worker.vm.provision "shell", run: "once", path: "./scripts/k8s-cert-config-gen.sh", privileged: true, env: {
          "EXPIRY" => EXPIRY,
          "ALGO" => ALGO,
          "SIZE" => SIZE,
          "C" => C,
          "L" => L,
          "O" => O,
          "OU" => OU,
          "ST" => ST,
          "SERVICE_CLUSTER_GATEWAY" => SERVICE_CLUSTER_GATEWAY,
          "GATEWAY_IP" => GATEWAY_IP,
          "DASHBOARD_USER_TOKEN" => DASHBOARD_USER_TOKEN,
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
          "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
          "CONTROLLER_IP" => CONTROLLER_IP
        }
        worker.vm.provision "shell", run: "once", privileged: false, env: {
            "IP" => WORKER_IPS_ARRAY[i - 1],
            "HOSTNAME" => "worker-#{i}",
            "CONTROLLER_IP" => CONTROLLER_IP
          }, inline: <<-SHELL
          echo "127.0.0.1 localhost" > /shared/hosts
          echo "$CONTROLLER_IP controller" >> /shared/hosts
          echo "$IP $HOSTNAME" >> /shared/hosts
        SHELL
      else
        worker.vm.provision "shell", run: "once", privileged: false, env: {
            "IP" => WORKER_IPS_ARRAY[i - 1],
            "HOSTNAME" => "worker-#{i}"
          }, inline: <<-SHELL
          echo "$IP $HOSTNAME" >> /shared/hosts
        SHELL
      end
      worker.vm.provision "shell", run: "once", path: "./scripts/init-k8s-worker.sh", privileged: true, env: {
        "EXPIRY" => EXPIRY,
        "ALGO" => ALGO,
        "SIZE" => SIZE,
        "C" => C,
        "L" => L,
        "OU" => OU,
        "ST" => ST,
        "GATEWAY_IP" => GATEWAY_IP,
        "CONTROLLER_IP" => CONTROLLER_IP,
        "INTERNAL_IP" => WORKER_IPS_ARRAY[i - 1],
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
        "NODE_IP" => WORKER_IPS_ARRAY[i - 1],
        "POD_CIDR" => POD_CIDR_ARRAY[i - 1],
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
      if PROVIDER == "hyperv"
        worker.trigger.after :reload do
          worker.vm.provision "shell", run: "always", privileged: true, inline: <<-SHELL
            modprobe br_netfilter
            swapoff -a
            mkdir -p /run/systemd/resolve
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
            echo "nameserver 8.8.4.4" >> /etc/resolv.conf
            echo "search localdomain" >> /etc/resolv.conf
            ln -s /etc/resolv.conf /run/systemd/resolve/resolv.conf
            mkdir -p /sys/fs/cgroup/systemd
            mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
            echo "[INFO] - worker node init done"
          SHELL
        end
        worker.vm.provision :reload
      end
    end
  end

  # k8s controller deploy
  config.vm.define "controller" do |controller|
    controller.vm.box = VM_BOX
    controller.vm.box_version = VM_BOX_VERSION
    controller.vm.hostname = "controller"
    controller.vm.provider PROVIDER do |v|
      v.memory = CONTROLLER_RAM
      v.cpus = CONTROLLER_CPU
      case PROVIDER
        when "virtualbox"
          v.name = "controller"
          v.gui = PROVIDER_GUI
        when "hyperv"
          v.vmname = "controller"
          v.maxmemory = CONTROLLER_RAM + 1024
        when "vmware_desktop"
          v.vmx["displayname"] = "controller"
          v.gui = PROVIDER_GUI
      end
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
          args: ["controller", HYPERV_SWITCH]
        }
      end
      controller.vm.provision "shell", run: "once", path: "./scripts/k8s-hyperv-ip-fix.sh", privileged: true, env: {
        "GATEWAY_IP" => GATEWAY_IP,
        "NET_RANGE" => NET_RANGE,
        "CURRENT_IP" => CONTROLLER_IP
      }
    else
      controller.vm.network "private_network", ip: CONTROLLER_IP
      controller.vm.synced_folder "./shared", "/shared"
      controller.vm.synced_folder "./addons", "/addons"
    end
    controller.vm.provision "shell", run: "once", path: "./scripts/init-k8s-controller.sh", privileged: true, env: {
      "ETCD_IP" => CONTROLLER_IP,
      "ETCD_NAME" => "controller",
      "ETCD_TOKEN" => ETCD_TOKEN,
      "HELM_VERSION" => HELM_VERSION,
      "CNI_VERSION" => CNI_VERSION,
      "ENCRYPTION_KEY" => ENCRYPTION_KEY,
      "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
      "CONTROLLER_IP" => CONTROLLER_IP,
      "GATEWAY_IP" => GATEWAY_IP,
      "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
      "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
      "SERVICE_CLUSTER_IP_RANGE" => SERVICE_CLUSTER_IP_RANGE,
      "CLUSTER_CIDR" => CLUSTER_CIDR,
      "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
    }
    if PROVIDER == "hyperv"
        controller.vm.provision :reload
    end
    controller.vm.provision "shell", run: "once", path: "./scripts/k8s-api-server-setup.sh", privileged: true
    controller.vm.provision "shell", run: "once", privileged: true, inline: <<-SHELL
      cp /shared/hosts /etc/hosts
    SHELL
    controller.vm.provision "shell", run: "once", privileged: false, env: {
        "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
        "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL
      }, inline: <<-SHELL
      # test etcd cluster
      sleep $SERVICE_RESTART_INTERVAL
      ETCDCTL_API=3 etcdctl member list \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=${KEYS_SHARED_FOLDER_PATH}/ca.pem \
        --cert=${KEYS_SHARED_FOLDER_PATH}/kubernetes.pem \
        --key=${KEYS_SHARED_FOLDER_PATH}/kubernetes-key.pem
      # test local healthz
      curl https://127.0.0.1:6443/healthz --cacert ${KEYS_SHARED_FOLDER_PATH}/ca.pem -s
      # apply addons
      kubectl apply -f /addons --kubeconfig ${CONFIGS_SHARED_FOLDER_PATH}/admin.kubeconfig
      sleep $SERVICE_RESTART_INTERVAL
      kubectl patch storageclass default \
        -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' \
        --kubeconfig ${CONFIGS_SHARED_FOLDER_PATH}/admin.kubeconfig
    SHELL
  end
end
