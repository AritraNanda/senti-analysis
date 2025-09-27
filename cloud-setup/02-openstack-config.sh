#!/bin/bash

# OpenStack Configuration for Kubernetes Deployment
# Creates networks, flavors, images, and security groups

echo "=== OpenStack Configuration for Private Cloud ==="

# Source OpenStack credentials
if [ -f ~/openstack-admin.sh ]; then
    source ~/openstack-admin.sh
elif [ -f /opt/stack/devstack/openrc ]; then
    source /opt/stack/devstack/openrc admin admin
else
    echo "ERROR: OpenStack credentials not found"
    exit 1
fi

# Verify OpenStack is working
echo "--- Verifying OpenStack Services ---"
openstack service list || {
    echo "ERROR: OpenStack services not accessible"
    exit 1
}

# Create flavors for different VM types
echo "--- Creating Custom Flavors ---"
openstack flavor create --ram 4096 --disk 20 --vcpus 2 k8s-master 2>/dev/null || echo "Flavor k8s-master already exists"
openstack flavor create --ram 2048 --disk 20 --vcpus 2 k8s-worker 2>/dev/null || echo "Flavor k8s-worker already exists"
openstack flavor create --ram 8192 --disk 40 --vcpus 4 k8s-ml-worker 2>/dev/null || echo "Flavor k8s-ml-worker already exists"

# Download and create Ubuntu 22.04 image
echo "--- Creating Ubuntu 22.04 Image ---"
if ! openstack image show ubuntu-22.04 >/dev/null 2>&1; then
    echo "Downloading Ubuntu 22.04 cloud image..."
    wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /tmp/ubuntu-22.04.img
    openstack image create --file /tmp/ubuntu-22.04.img --disk-format qcow2 --container-format bare --public ubuntu-22.04
    rm -f /tmp/ubuntu-22.04.img
else
    echo "Ubuntu 22.04 image already exists"
fi

# Create key pair for VM access
echo "--- Creating Key Pair ---"
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
fi

openstack keypair create --public-key ~/.ssh/id_rsa.pub k8s-keypair 2>/dev/null || echo "Key pair already exists"

# Create security groups
echo "--- Creating Security Groups ---"

# Kubernetes security group
if ! openstack security group show k8s-cluster >/dev/null 2>&1; then
    openstack security group create k8s-cluster --description "Kubernetes cluster security group"
    
    # SSH access
    openstack security group rule create --protocol tcp --dst-port 22 k8s-cluster
    
    # Kubernetes API server
    openstack security group rule create --protocol tcp --dst-port 6443 k8s-cluster
    
    # etcd
    openstack security group rule create --protocol tcp --dst-port 2379:2380 k8s-cluster
    
    # Kubelet API
    openstack security group rule create --protocol tcp --dst-port 10250 k8s-cluster
    
    # NodePort services
    openstack security group rule create --protocol tcp --dst-port 30000:32767 k8s-cluster
    
    # Flannel/Calico CNI
    openstack security group rule create --protocol udp --dst-port 8472 k8s-cluster
    
    # ICMP (ping)
    openstack security group rule create --protocol icmp k8s-cluster
    
    # Allow all traffic within security group
    openstack security group rule create --protocol tcp --remote-group k8s-cluster k8s-cluster
    openstack security group rule create --protocol udp --remote-group k8s-cluster k8s-cluster
else
    echo "Security group k8s-cluster already exists"
fi

# Web services security group
if ! openstack security group show web-services >/dev/null 2>&1; then
    openstack security group create web-services --description "Web services security group"
    
    # HTTP/HTTPS
    openstack security group rule create --protocol tcp --dst-port 80 web-services
    openstack security group rule create --protocol tcp --dst-port 443 web-services
    
    # Application ports
    openstack security group rule create --protocol tcp --dst-port 8000 web-services  # API
    openstack security group rule create --protocol tcp --dst-port 8001 web-services  # ML Model
    openstack security group rule create --protocol tcp --dst-port 5173 web-services  # Frontend dev
    
    # Monitoring ports
    openstack security group rule create --protocol tcp --dst-port 9090 web-services  # Prometheus
    openstack security group rule create --protocol tcp --dst-port 3000 web-services  # Grafana
else
    echo "Security group web-services already exists"
fi

# Create networks
echo "--- Creating Networks ---"

# Internal network for Kubernetes
if ! openstack network show k8s-internal >/dev/null 2>&1; then
    openstack network create k8s-internal
    openstack subnet create --network k8s-internal --subnet-range 10.0.1.0/24 --dns-nameserver 8.8.8.8 k8s-internal-subnet
else
    echo "Network k8s-internal already exists"
fi

# List available networks
echo "--- Available Networks ---"
openstack network list

# List available flavors
echo "--- Available Flavors ---"
openstack flavor list

# List available images
echo "--- Available Images ---"
openstack image list

# Create cloud-init script for VMs
echo "--- Creating Cloud-Init Script ---"
tee ~/k8s-cloud-init.yaml << 'EOF'
#cloud-config
users:
  - default
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... # Will be replaced with actual key

package_update: true
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release

runcmd:
  - echo "VM initialized for Kubernetes" > /tmp/init-complete
  - systemctl enable ssh
  - systemctl start ssh

write_files:
  - path: /etc/ssh/sshd_config.d/k8s.conf
    content: |
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no

final_message: "Kubernetes VM is ready for cluster setup"
EOF

# Replace SSH key in cloud-init
sed -i "s|ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC...|$(cat ~/.ssh/id_rsa.pub)|" ~/k8s-cloud-init.yaml

echo "=== OpenStack Configuration Complete ==="
echo ""
echo "Available resources:"
echo "- Networks: k8s-internal, public"
echo "- Flavors: k8s-master, k8s-worker, k8s-ml-worker"
echo "- Image: ubuntu-22.04"
echo "- Security Groups: k8s-cluster, web-services"
echo "- Key Pair: k8s-keypair"
echo ""
echo "Next: Run 03-vm-creation.sh to create Kubernetes VMs"