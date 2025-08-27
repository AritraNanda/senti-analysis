#!/bin/bash

# Private Cloud Setup Prerequisites for Sentiment Analyzer
# Target: Ubuntu Server 22.04 LTS on laptop

echo "=== Private Cloud Infrastructure Setup Phase 1 ==="

# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install essential tools
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm

# 3. Install Docker (Container Runtime)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 4. Install Kubernetes (K3s - Lightweight Kubernetes)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# 5. Install kubectl
sudo snap install kubectl --classic

# 6. Install Helm (Package Manager for Kubernetes)
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update
sudo apt install -y helm

# 7. Install Prometheus & Grafana prerequisites
sudo groupadd prometheus
sudo useradd -g prometheus --no-create-home --shell /bin/false prometheus

# 8. Setup directories
sudo mkdir -p /opt/cloud-setup/{prometheus,grafana,mongodb}
sudo chown -R $USER:$USER /opt/cloud-setup

# 9. Configure Docker for non-root user
sudo usermod -aG docker $USER

# 10. Install Istio Service Mesh (for advanced load balancing)
curl -L https://istio.io/downloadIstio | sh -
sudo mv istio-*/bin/istioctl /usr/local/bin/

echo "=== Prerequisites Installation Complete ==="
echo "Please reboot the system and run the next phase script"
echo "Reboot command: sudo reboot"
