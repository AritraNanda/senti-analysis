#!/bin/bash

# OpenNebula Compute Node Installation Script  
# For Device 2+ in multi-device setup (4GB RAM, 20GB storage)
# Updated for Ubuntu 22.04+ with modern GPG keyring approach

echo "=== OpenNebula Compute Node Installation ==="

# Check if this is Device 1 (should use frontend script instead)
if systemctl is-active --quiet opennebula-sunstone; then
    echo "WARNING: This appears to be a frontend node. Use opennebula-frontend-install.sh instead."
    exit 1
fi

# Check system requirements
echo "--- System Requirements Check ---"
RAM=$(free -g | grep '^Mem:' | awk '{print $2}')
DISK=$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')

if [ "$RAM" -lt 3 ]; then
    echo "WARNING: Minimum 3GB RAM recommended for compute node (found ${RAM}GB)"
fi

if [ "$DISK" -lt 10 ]; then
    echo "WARNING: Minimum 10GB disk space recommended (found ${DISK}GB available)"
fi

# Prerequisites
echo "--- Installing Prerequisites ---"
sudo apt update
sudo apt install -y \
    ruby ruby-dev \
    make gcc g++ \
    sqlite3 libsqlite3-dev \
    lsb-release \
    curl wget \
    gnupg2 \
    ca-certificates \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients

# Add OpenNebula repository (modern approach - no apt-key deprecation warnings)
echo "--- Adding OpenNebula Repository ---"
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list

sudo apt update

# Install ONLY compute node components
echo "--- Installing Compute Node Components ---"
sudo apt install -y \
    opennebula-node \
    opennebula-rubygems

# Create oneadmin user if it doesn't exist  
if ! id "oneadmin" &>/dev/null; then
    echo "--- Creating oneadmin user ---"
    sudo adduser --system --group --home /var/lib/one --shell /bin/bash oneadmin
fi

# Configure SSH directory for oneadmin
echo "--- Configuring SSH Access ---"
sudo mkdir -p /var/lib/one/.ssh
sudo chown oneadmin:oneadmin /var/lib/one/.ssh
sudo chmod 700 /var/lib/one/.ssh

# Enable and start libvirt services
echo "--- Configuring Virtualization ---"
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Add oneadmin to libvirt group
sudo usermod -a -G libvirt oneadmin

# Get system info
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
HOSTNAME=$(hostname)

echo ""
echo "=== OpenNebula Compute Node Installation Complete ==="
echo ""
echo "📊 System Info:"
echo "  - RAM: ${RAM}GB"
echo "  - Available Disk: ${DISK}GB"
echo "  - Host IP: $HOST_IP"
echo "  - Hostname: $HOSTNAME"
echo ""
echo "🔧 Next Steps:"
echo ""
echo "1. Copy SSH public key from frontend (Device 1):"
echo "   On Device 1, run: sudo cat /var/lib/one/.ssh/id_rsa.pub"
echo "   On this device, run: echo 'PUBLIC_KEY_CONTENT' | sudo tee /var/lib/one/.ssh/authorized_keys"
echo "   Then run: sudo chown oneadmin:oneadmin /var/lib/one/.ssh/authorized_keys"
echo "   And: sudo chmod 600 /var/lib/one/.ssh/authorized_keys"
echo ""
echo "2. Register this node on frontend (Device 1):"
echo "   sudo -u oneadmin onehost create $HOSTNAME -i kvm -v kvm"
echo ""
echo "3. Verify node registration:"
echo "   sudo -u oneadmin onehost list"
echo ""
echo "4. Test connectivity from frontend:"
echo "   sudo -u oneadmin ssh oneadmin@$HOST_IP"
echo ""

# Create helper script for compute node management
cat > ~/compute-node-commands.sh << 'EOF'
#!/bin/bash
# Compute Node Helper Commands

echo "=== Compute Node Management Commands ==="
echo ""
echo "Service Status:"
echo "  sudo systemctl status libvirtd"
echo "  sudo virsh list --all"
echo ""
echo "SSH Configuration:"
echo "  ls -la /var/lib/one/.ssh/"
echo "  sudo cat /var/lib/one/.ssh/authorized_keys"
echo ""
echo "System Resources:"
echo "  free -h"
echo "  df -h"
echo "  sudo virsh nodeinfo"
echo ""
echo "Network Info:"
echo "  ip addr show"
echo "  hostname"
EOF

chmod +x ~/compute-node-commands.sh

echo "💡 Helper script created: ~/compute-node-commands.sh"
echo ""
echo "⚠️  IMPORTANT: Remember to configure SSH key access from the frontend node!"