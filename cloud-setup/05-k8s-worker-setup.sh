#!/bin/bash

# Kubernetes Worker Node Setup on OpenStack VMs
# Run this script on each worker VM

echo "=== Kubernetes Worker Node Setup ==="

# Check hostname to identify the node
HOSTNAME=$(hostname)
echo "Setting up worker node: $HOSTNAME"

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "--- Installing Docker ---"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Configure Docker daemon
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo usermod -aG docker $USER

# Install Kubernetes components
echo "--- Installing Kubernetes Components ---"
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Configure kubelet
NODE_IP=$(hostname -I | awk '{print $1}')
sudo tee /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$NODE_IP
EOF

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure kernel modules
sudo modprobe br_netfilter
echo 'br_netfilter' | sudo tee /etc/modules-load.d/k8s.conf

# Configure sysctl
sudo tee /etc/sysctl.d/k8s.conf << 'EOF'
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# ML Worker specific setup (for k8s-worker-2)
if [ "$HOSTNAME" = "k8s-worker-2" ]; then
    echo "--- ML Worker Specific Setup ---"
    
    # Install Python and ML dependencies
    sudo apt install -y python3 python3-pip python3-venv
    pip3 install --user torch torchvision torchaudio transformers
    
    # Install NVIDIA drivers if GPU is available
    if lspci | grep -i nvidia; then
        echo "NVIDIA GPU detected, installing drivers..."
        sudo apt install -y nvidia-driver-470 nvidia-docker2
        sudo systemctl restart docker
    fi
    
    # Label node for ML workloads (will be done from master)
    echo "Node will be labeled for ML workloads"
fi

# Storage node specific setup (for k8s-storage)
if [ "$HOSTNAME" = "k8s-storage" ]; then
    echo "--- Storage Node Specific Setup ---"
    
    # Create directories for persistent volumes
    sudo mkdir -p /opt/k8s-storage/{mongodb,prometheus,grafana}
    sudo chmod 777 /opt/k8s-storage/{mongodb,prometheus,grafana}
    
    # Install NFS utils for shared storage
    sudo apt install -y nfs-common
fi

echo "--- Worker Node Setup Complete ---"
echo "Node IP: $NODE_IP"
echo "Hostname: $HOSTNAME"
echo ""
echo "To join this node to the Kubernetes cluster:"
echo "1. Get the join command from the master node:"
echo "   ssh ubuntu@<master-ip> 'cat /home/ubuntu/join-command'"
echo "2. Run the join command with sudo on this node"
echo ""
echo "Example join command:"
echo "sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"