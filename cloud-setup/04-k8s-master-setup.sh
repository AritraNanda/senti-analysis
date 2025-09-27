#!/bin/bash

# Kubernetes Master Node Setup on OpenStack VM
# Run this script on the master VM

echo "=== Kubernetes Master Node Setup ==="

# Check if running on the correct VM
if [ "$(hostname)" != "k8s-master" ]; then
    echo "WARNING: This script should be run on k8s-master VM"
    echo "Current hostname: $(hostname)"
fi

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
sudo tee /etc/default/kubelet << 'EOF'
KUBELET_EXTRA_ARGS=--node-ip=$(hostname -I | awk '{print $1}')
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

# Initialize Kubernetes cluster
echo "--- Initializing Kubernetes Cluster ---"
MASTER_IP=$(hostname -I | awk '{print $1}')
echo "Master IP: $MASTER_IP"

# Initialize cluster with specific pod network CIDR
sudo kubeadm init \
    --apiserver-advertise-address=$MASTER_IP \
    --pod-network-cidr=10.244.0.0/16 \
    --service-cidr=10.96.0.0/12 \
    --node-name k8s-master

if [ $? -eq 0 ]; then
    echo "Kubernetes cluster initialized successfully"
else
    echo "ERROR: Kubernetes cluster initialization failed"
    exit 1
fi

# Configure kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Configure kubectl for current user (if different)
if [ "$USER" != "ubuntu" ]; then
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
fi

# Install Flannel CNI
echo "--- Installing Flannel CNI ---"
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Wait for system pods to be ready
echo "--- Waiting for system pods ---"
kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s

# Generate join command for worker nodes
echo "--- Generating Join Command ---"
JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)
echo "$JOIN_COMMAND" > /home/ubuntu/join-command
sudo chmod +r /home/ubuntu/join-command

echo "Join command saved to /home/ubuntu/join-command"
echo "Copy this command to worker nodes:"
echo "$JOIN_COMMAND"

# Install Helm
echo "--- Installing Helm ---"
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install -y helm

# Install MetalLB for LoadBalancer services
echo "--- Installing MetalLB ---"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=90s

# Configure MetalLB address pool
INTERNAL_IP_RANGE="10.0.1.100-10.0.1.150"  # Adjust based on your OpenStack network
tee ~/metallb-config.yaml << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $INTERNAL_IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
EOF

kubectl apply -f ~/metallb-config.yaml

# Install NGINX Ingress Controller
echo "--- Installing NGINX Ingress Controller ---"
helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace ingress-nginx --create-namespace

# Display cluster status
echo "--- Cluster Status ---"
kubectl get nodes
kubectl get pods --all-namespaces

echo "=== Kubernetes Master Setup Complete ==="
echo ""
echo "Cluster Information:"
echo "- Master IP: $MASTER_IP"
echo "- Pod Network: 10.244.0.0/16"
echo "- Service Network: 10.96.0.0/12"
echo ""
echo "To add worker nodes, run the following command on each worker:"
echo "$JOIN_COMMAND"
echo ""
echo "kubectl configuration is available at:"
echo "- /home/ubuntu/.kube/config"
echo ""
echo "Next steps:"
echo "1. SSH to worker nodes and run the join command"
echo "2. Verify nodes with: kubectl get nodes"
echo "3. Deploy applications"