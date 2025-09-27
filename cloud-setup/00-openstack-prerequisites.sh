#!/bin/bash

# OpenStack DevStack Prerequisites Installation
# For Private Cloud Infrastructure Setup

echo "=== OpenStack DevStack Prerequisites Installation ==="

# Check system requirements
echo "--- System Requirements Check ---"
RAM=$(free -g | grep '^Mem:' | awk '{print $2}')
DISK=$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')

if [ "$RAM" -lt 12 ]; then
    echo "WARNING: Minimum 12GB RAM recommended for OpenStack (found ${RAM}GB)"
fi

if [ "$DISK" -lt 80 ]; then
    echo "WARNING: Minimum 80GB disk space recommended (found ${DISK}GB available)"
fi

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y \
    git \
    curl \
    wget \
    vim \
    htop \
    net-tools \
    bridge-utils \
    python3-dev \
    python3-pip \
    python3-venv \
    build-essential \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg8-dev \
    zlib1g-dev \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager

# Configure virtualization
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Install Docker for containerized services
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER

# Configure system limits for OpenStack
sudo tee -a /etc/security/limits.conf << EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Configure kernel parameters
sudo tee -a /etc/sysctl.conf << EOF
# OpenStack networking requirements
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
vm.swappiness=10
EOF

# Apply sysctl changes
sudo sysctl -p

# Configure firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp     # Horizon dashboard
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 5000/tcp   # Keystone
sudo ufw allow 8774/tcp   # Nova API
sudo ufw allow 8776/tcp   # Cinder API
sudo ufw allow 9292/tcp   # Glance API
sudo ufw allow 9696/tcp   # Neutron API
sudo ufw allow 6080/tcp   # Nova VNC
sudo ufw allow 8080/tcp   # Swift proxy

# Create stack user for DevStack
sudo useradd -s /bin/bash -d /opt/stack -m stack
sudo chmod +x /opt/stack
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

# Prepare DevStack directory
sudo -u stack git clone https://opendev.org/openstack/devstack /opt/stack/devstack

# Create basic local.conf for DevStack
sudo -u stack tee /opt/stack/devstack/local.conf << 'EOF'
[[local|localrc]]

# Passwords
ADMIN_PASSWORD=admin123
DATABASE_PASSWORD=admin123
RABBIT_PASSWORD=admin123
SERVICE_PASSWORD=admin123

# Services to enable
enable_service rabbit mysql key

# Nova services
enable_service n-api n-cpu n-cond n-sch n-novnc n-cauth

# Glance services
enable_service g-api g-reg

# Cinder services
enable_service cinder c-api c-vol c-sch c-bak

# Neutron services
enable_service neutron q-svc q-agt q-dhcp q-l3 q-meta

# Horizon dashboard
enable_service horizon

# Swift services (optional)
# enable_service s-proxy s-object s-container s-account

# Heat services (orchestration)
enable_service heat h-api h-api-cfn h-api-cw h-eng

# Logs
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True

# Network configuration
HOST_IP=192.168.1.100  # Change to your actual IP
FLOATING_RANGE=192.168.1.224/27
PUBLIC_NETWORK_GATEWAY=192.168.1.1
Q_FLOATING_ALLOCATION_POOL=start=192.168.1.225,end=192.168.1.250

# Storage
VOLUME_GROUP="stack-volumes"
VOLUME_NAME_PREFIX="volume-"
VOLUME_BACKING_FILE_SIZE=10G

# Performance optimizations
DATABASE_TYPE=mysql
RECLONE=no
EOF

echo "=== Prerequisites Installation Complete ==="
echo "Next steps:"
echo "1. Logout and login again (for group changes)"
echo "2. Edit /opt/stack/devstack/local.conf with your network settings"
echo "3. Run: sudo -u stack /opt/stack/devstack/stack.sh"
echo ""
echo "IMPORTANT: Update HOST_IP and network ranges in local.conf before proceeding!"