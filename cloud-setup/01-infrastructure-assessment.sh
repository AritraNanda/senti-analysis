#!/bin/bash

# Cloud Infrastructure Assessment and Setup
# Phase 1B: System Configuration and Validation

echo "=== Infrastructure Assessment Phase ==="

# 1. System Resource Check
echo "--- System Resources ---"
echo "CPU Cores: $(nproc)"
echo "RAM: $(free -h | grep '^Mem:' | awk '{print $2}')"
echo "Disk Space: $(df -h / | tail -1 | awk '{print $4}')"
echo "Network Interfaces:"
ip addr show | grep inet

# 2. Validate installations
echo "--- Validating Installations ---"
docker --version
kubectl version --client
helm version
k3s --version

# 3. Setup networking for private cloud
echo "--- Network Configuration ---"
# Configure firewall for services
sudo ufw enable
sudo ufw allow 22     # SSH
sudo ufw allow 80     # HTTP
sudo ufw allow 443    # HTTPS
sudo ufw allow 6443   # Kubernetes API
sudo ufw allow 8000   # API Service
sudo ufw allow 8001   # ML Model Service
sudo ufw allow 5173   # Frontend
sudo ufw allow 9090   # Prometheus
sudo ufw allow 3000   # Grafana
sudo ufw allow 27017  # MongoDB

# 4. Create cloud user for services
sudo useradd -m -s /bin/bash clouduser
sudo usermod -aG docker clouduser
sudo usermod -aG sudo clouduser

# 5. Setup SSL certificates (self-signed for development)
sudo mkdir -p /etc/ssl/private-cloud
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private-cloud/private-cloud.key \
    -out /etc/ssl/private-cloud/private-cloud.crt \
    -subj "/C=IN/ST=State/L=City/O=PrivateCloud/CN=sentiment-analyzer.local"

# 6. Configure hosts file for local DNS
echo "127.0.0.1 sentiment-analyzer.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 api.sentiment-analyzer.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 ml.sentiment-analyzer.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 monitor.sentiment-analyzer.local" | sudo tee -a /etc/hosts

echo "=== Infrastructure Assessment Complete ==="
echo "Ready for Kubernetes cluster setup"
