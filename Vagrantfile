# encoding: utf-8
# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

current_dir = File.dirname(File.expand_path(__FILE__))
secrets = YAML.load_file("#{current_dir}/secrets.yaml")
resources = YAML.load_file("#{current_dir}/resources.yaml")
network = YAML.load_file("#{current_dir}/network.yaml")
cert = YAML.load_file("#{current_dir}/cert.yaml")
addons = YAML.load_file("#{current_dir}/addons.yaml")

DOWNLOAD_DISTRS = false                                         # download k8s bins, common bins and deb packages while deploying cluster, first init should be done with [true]

APPLY_INFRASTRUCTURE_COMPONENTS = addons["infrastructure"]      # apply DB and other components in infrastructure namespace
APPLY_TEAMCITY = addons["teamcity"]                             # apply teamcity CI-CD tool in teamcity namespace
APPLY_BITBUCKET = addons["bitbucket"]                           # apply bitbucket VCS tool in bitbucket namespace
APPLY_JIRA = addons["jira"]                                     # apply jira task tracker tool in jira namespace
APPLY_NEXUS = addons["nexus"]                                   # apply nexus registry tool in nexus namespace
APPLY_SONARQUBE = addons["sonarqube"]                           # apply sonarqube code quality tool in sonarqube namespace

PROVIDER = resources["provider"]                                # vmware_desktop, virtualbox, hyperv
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
POSTGRES_PASSWORD = secrets["postgres_password"]                # postgres password

NFS_CPU = resources["nfs_cpu"]                                  # CPU qty for nfs
NFS_RAM = resources["nfs_ram"]                                  # RAM size for nfs
CONTROLLER_CPU = resources["controller_cpu"]                    # CPU qty for controller
CONTROLLER_RAM = resources["controller_ram"]                    # RAM size for controller
WORKER_CPU = resources["worker_cpu"]                            # CPU qty for worker
WORKER_RAM = resources["worker_ram"]                            # RAM size for worker

GATEWAY_IP = network["gateway_ip"]                              # Hyper-V gateway IP
NET_MASK = network["net_mask"]                                  # net mask for Hyper-V
NET_RANGE = network["net_range"]                                # net range for Hyper-V
DNS_IP_1 = network["dns_ip_1"]                                  # main worker node DNS ip
DNS_IP_2 = network["dns_ip_2"]                                  # second worker node DNS ip
NFS_IP = network["nfs_ip"]                                      # nfs node
CONTROLLER_IP = network["controller_ip"]                        # controller + etcd node
WORKER_IPS_ARRAY = network["worker_ips"]                        # worker nodes [can be scaled]
POD_CIDR_ARRAY = network["pod_cidrs"]                           # pod cidr array
CLUSTER_CIDR = network["cluster_cidr"]                          # cluster cidr
SERVICE_CLUSTER_IP_RANGE = network["service_cluster_ip_range"]  # cluster ip range
SERVICE_CLUSTER_DNS = network["service_cluster_dns"]            # cluster dns ip
SERVICE_CLUSTER_GATEWAY = network["service_cluster_gateway"]    # cluster gateway ip

ENCRYPTION_KEY = secrets["k8s_encrypt_key"]                     # k8s encryption key
ETCD_TOKEN = secrets["etcd_token"]                              # etcd token

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

SERVICE_RESTART_INTERVAL = 5                                    # systemd service restart interval

# network config check
if WORKER_IPS_ARRAY.length != POD_CIDR_ARRAY.length
  puts "[ERROR] - nodes IP count not equal to pods CIDR count, skipping VMs deploy..."
  return
end

# Prepare routes and hosts content
routes_content = "#!/bin/bash\n"
hosts_content = "127.0.0.1 localhost\n#{CONTROLLER_IP} controller\n"
counter = 0
WORKER_IPS_ARRAY.each do |worker_ip|
  routes_content += "ip route add #{POD_CIDR_ARRAY[counter]} via #{worker_ip}; "
  hosts_content += "#{worker_ip} worker-#{counter + 1}\n"
  counter += 1
end

# Write hosts_content to files
File.write('./shared/hosts', hosts_content)

Vagrant.configure(2) do |config|

  # nfs deploy
  config.vm.define "nfs" do |nfs|
    nfs.vm.box = VM_BOX
    nfs.vm.box_version = VM_BOX_VERSION
    nfs.vm.hostname = "nfs"
    nfs.vm.provider PROVIDER do |v|
      v.memory = NFS_RAM
      v.cpus = NFS_CPU
      case PROVIDER
        when "virtualbox"
          v.name = "nfs [#{Time.now.strftime("%d-%m-%Y %H-%M-%S")}]"
          v.gui = PROVIDER_GUI
        when "hyperv"
          v.vmname = "nfs"
          v.maxmemory = NFS_RAM + 1024
        when "vmware_desktop"
          v.vmx["displayname"] = "nfs [#{Time.now.strftime("%d-%m-%Y %H-%M-%S")}]"
          v.gui = PROVIDER_GUI
      end
    end
    if PROVIDER == "hyperv"
      nfs.trigger.before :up do |up_trigger|
        up_trigger.info = "Creating 'k8s-net' Hyper-V switch if it does not exist..."
        up_trigger.run = {
          privileged: "true", 
          powershell_elevated_interactive: "true", 
          path: "./scripts/powershell/create-nat-hyperv-switch.ps1",
          args: [HYPERV_SWITCH, GATEWAY_IP, NET_MASK, NET_RANGE]
        }
      end
      nfs.vm.synced_folder "./shared", "/shared", type: "smb", mount_options: ["username=#{SMB_USER}","password=#{SMB_PASSWORD}"], smb_password: SMB_PASSWORD, smb_username: SMB_USER
      nfs.trigger.before :reload do |reload_trigger|
        reload_trigger.info = "Setting Hyper-V switch to 'k8s-net' to allow for static IP..."
        reload_trigger.run = {
          privileged: "true", 
          powershell_elevated_interactive: "true", 
          path: "./scripts/powershell/set-hyperv-switch.ps1",
          args: ["nfs", HYPERV_SWITCH]
        }
      end
      nfs.vm.provision "shell", run: "once", path: "./scripts/k8s-hyperv-ip-fix.sh", privileged: true, env: {
        "GATEWAY_IP" => GATEWAY_IP,
        "NET_RANGE" => NET_RANGE,
        "CURRENT_IP" => NFS_IP
      }
      nfs.vm.provision :reload
    else
      nfs.vm.network "private_network", ip: NFS_IP
      nfs.vm.synced_folder "./shared", "/shared"
    end
    if DOWNLOAD_DISTRS == true
      nfs.vm.provision "shell", run: "once", privileged: true, env: {
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH
        }, inline: <<-SHELL
        mkdir -p $DISTR_SHARED_FOLDER_PATH/apt_packages/nfs
        cd $DISTR_SHARED_FOLDER_PATH/apt_packages/nfs
        apt-get download keyutils libnfsidmap1 nfs-common nfs-kernel-server rpcbind
      SHELL
    end
    nfs.vm.provision "shell", run: "once", privileged: true, env: {
        "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH
      }, inline: <<-SHELL
      dpkg -i $DISTR_SHARED_FOLDER_PATH/apt_packages/nfs/*.deb
      mkdir -p \
        /mnt/data/bitbucket \
        /mnt/data/postgres \
        /mnt/data/jira \
        /mnt/data/nexus \
        /mnt/data/sonarqube \
        /mnt/data/teamcity
      echo "/mnt/data/bitbucket    *(rw,sync,no_subtree_check,insecure,no_root_squash)" > /etc/exports
      echo "/mnt/data/postgres     *(rw,sync,no_subtree_check,insecure,no_root_squash)" >> /etc/exports
      echo "/mnt/data/jira         *(rw,sync,no_subtree_check,insecure,no_root_squash)" >> /etc/exports
      echo "/mnt/data/nexus        *(rw,sync,no_subtree_check,insecure,no_root_squash)" >> /etc/exports
      echo "/mnt/data/sonarqube    *(rw,sync,no_subtree_check,insecure,no_root_squash)" >> /etc/exports
      echo "/mnt/data/teamcity     *(rw,sync,no_subtree_check,insecure,no_root_squash)" >> /etc/exports
      exportfs -ra
    SHELL
  end

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
            v.name = "worker-#{i} [#{Time.now.strftime("%d-%m-%Y %H-%M-%S")}]"
            v.gui = PROVIDER_GUI
          when "hyperv"
            v.vmname = "worker-#{i}"
            v.maxmemory = WORKER_RAM + 1024
          when "vmware_desktop"
            v.vmx["displayname"] = "worker-#{i} [#{Time.now.strftime("%d-%m-%Y %H-%M-%S")}]"
            v.gui = PROVIDER_GUI
        end
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
          "NET_RANGE" => NET_RANGE,
          "CURRENT_IP" => WORKER_IPS_ARRAY[i - 1]
        }
        worker.vm.provision :reload
      else
        worker.vm.network "private_network", ip: WORKER_IPS_ARRAY[i - 1]
        worker.vm.synced_folder "./shared", "/shared"
      end
      if i == 1
        if DOWNLOAD_DISTRS == true
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
          worker.vm.provision "shell", run: "once", privileged: true, env: {
              "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH
            }, inline: <<-SHELL
            mkdir -p $DISTR_SHARED_FOLDER_PATH/apt_packages/k8s
            cd $DISTR_SHARED_FOLDER_PATH/apt_packages/k8s
            apt-get download conntrack ipset iptables keyutils libip6tc2 libipset13 libnetfilter-conntrack3 libnfnetlink0 libnfsidmap1 nfs-common rpcbind socat
          SHELL
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
          "DISTR_SHARED_FOLDER_PATH" => DISTR_SHARED_FOLDER_PATH,
          "KEYS_SHARED_FOLDER_PATH" => KEYS_SHARED_FOLDER_PATH,
          "CONFIGS_SHARED_FOLDER_PATH" => CONFIGS_SHARED_FOLDER_PATH,
          "CONTROLLER_IP" => CONTROLLER_IP
        }
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
        "DNS_IP_1" => DNS_IP_1,
        "DNS_IP_2" => DNS_IP_2,
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
        "SERVICE_RESTART_INTERVAL" => SERVICE_RESTART_INTERVAL,
        "ROUTES" => routes_content,
        "NFS_IP" => NFS_IP
      }
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
          v.name = "controller [#{Time.now.strftime("%d-%m-%Y %H-%M-%S")}]"
          v.gui = PROVIDER_GUI
        when "hyperv"
          v.vmname = "controller"
          v.maxmemory = CONTROLLER_RAM + 1024
        when "vmware_desktop"
          v.vmx["displayname"] = "controller [#{Time.now.strftime("%d-%m-%Y %H-%M-%S")}]"
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
      controller.vm.provision :reload
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
    controller.vm.provision "shell", run: "always", privileged: true, inline: <<-SHELL
      # copy manifests
      if [ -d /addons/kube-system ]; then
        mkdir -p /manifests
        rm -Rf /manifests/*
        cp -r /addons/* /manifests
        echo "\n[INFO] - manifests updated.\n"
      else
        echo "\n[INFO] - manifests not updated, addons folder is empty.\n"
      fi
    SHELL
    if APPLY_INFRASTRUCTURE_COMPONENTS == true
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs",
        "POSTGRES_PASSWORD" => POSTGRES_PASSWORD
        }, inline: <<-SHELL
        # create infrastructure namespace
        kubectl create namespace infrastructure --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -  
        # create secret for postgres
        kubectl create secret generic postgres-secret --from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD} -n infrastructure \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # install opensearch postgres and hazelcast infrastructure components
        kubectl apply -f /manifests/infrastructure --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig
        echo "\n[INFO] - infrastructure components are in INSTALLED mode.\n"
      SHELL
    else
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # delete infrastructure namespase and pv
        kubectl delete namespace infrastructure --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        kubectl delete pv postgres-data \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        echo "\n[INFO] - infrastructure components are in UNINSTALLED mode.\n"
      SHELL
    end
    if APPLY_TEAMCITY == true
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # create teamcity namespace
        kubectl create namespace teamcity --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # install teamcity
        kubectl apply -f /manifests/teamcity --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig
        echo "\n[INFO] - teamcity component is in INSTALLED mode.\n"
      SHELL
    else
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # delete teamcity namespase and pv
        kubectl delete namespace teamcity --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        kubectl delete pv teamcity-data \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        echo "\n[INFO] - teamcity component is in UNINSTALLED mode.\n"
      SHELL
    end
    if APPLY_BITBUCKET == true
      controller.vm.provision "shell", run: "always", privileged: false, env: {
          "CONFIGS_FOLDER_PATH" => "/k8s/configs",
          "POSTGRES_PASSWORD" => POSTGRES_PASSWORD
        }, inline: <<-SHELL
        # create bitbucket namespace
        kubectl create namespace bitbucket --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # create secret for postgres
        kubectl create secret generic postgres-secret --from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD} -n bitbucket \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # install bitbucket
        kubectl apply -f /manifests/bitbucket --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig
        echo "\n[INFO] - bitbucket component is in INSTALLED mode.\n"
      SHELL
    else
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # delete bitbucket namespase and pv
        kubectl delete namespace bitbucket --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        kubectl delete pv bitbucket-data \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        echo "\n[INFO] - bitbucket component is in UNINSTALLED mode.\n"
      SHELL
    end
    if APPLY_JIRA == true
      controller.vm.provision "shell", run: "always", privileged: false, env: {
          "CONFIGS_FOLDER_PATH" => "/k8s/configs",
          "POSTGRES_PASSWORD" => POSTGRES_PASSWORD
        }, inline: <<-SHELL
        # create jira namespace
        kubectl create namespace jira --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # install jira
        kubectl apply -f /manifests/jira --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig
        echo "\n[INFO] - jira component is in INSTALLED mode.\n"
      SHELL
    else
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # delete jira namespase and pv
        kubectl delete namespace jira --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        kubectl delete pv jira-data \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        echo "\n[INFO] - jira component is in UNINSTALLED mode.\n"
      SHELL
    end
    if APPLY_NEXUS == true
      controller.vm.provision "shell", run: "always", privileged: false, env: {
          "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # create nexus namespace
        kubectl create namespace nexus --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # install nexus
        kubectl apply -f /manifests/nexus --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig
        echo "\n[INFO] - nexus component is in INSTALLED mode.\n"
      SHELL
    else
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # delete nexus namespase and pv
        kubectl delete namespace nexus --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        kubectl delete pv nexus-data \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        echo "\n[INFO] - nexus component is in UNINSTALLED mode.\n"
      SHELL
    end
    if APPLY_SONARQUBE == true
      controller.vm.provision "shell", run: "always", privileged: false, env: {
          "CONFIGS_FOLDER_PATH" => "/k8s/configs",
          "POSTGRES_PASSWORD" => POSTGRES_PASSWORD
        }, inline: <<-SHELL
        # create sonarqube namespace
        kubectl create namespace sonarqube --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # create secret for postgres
        kubectl create secret generic postgres-secret --from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD} -n sonarqube \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --dry-run=client -o yaml | \
          kubectl apply --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig -f -
        # install sonarqube
        kubectl apply -f /manifests/sonarqube --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig
        echo "\n[INFO] - sonarqube component is in INSTALLED mode.\n"
      SHELL
    else
      controller.vm.provision "shell", run: "always", privileged: false, env: {
        "CONFIGS_FOLDER_PATH" => "/k8s/configs"
        }, inline: <<-SHELL
        # delete sonarqube namespase and pv
        kubectl delete namespace sonarqube --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        kubectl delete pv sonarqube-data \
          --kubeconfig ${CONFIGS_FOLDER_PATH}/admin.kubeconfig --ignore-not-found
        echo "\n[INFO] - sonarqube component is in UNINSTALLED mode.\n"
      SHELL
    end
  end
  
end
