#!/bin/bash

# OpenNebula Frontend + Compute Node Installation Script
# For Device 1 in multi-device setup (4GB RAM, 20GB storage)
# Updated for Ubuntu 22.04+ with modern GPG keyring approach

echo "=== OpenNebula Frontend + Compute Node Installation ==="

# Check system requirements
echo "--- System Requirements Check ---"
RAM=$(free -g | grep '^Mem:' | awk '{print $2}')
DISK=$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')

if [ "$RAM" -lt 4 ]; then
    echo "WARNING: Minimum 4GB RAM recommended for OpenNebula (found ${RAM}GB)"
fi

if [ "$DISK" -lt 15 ]; then
    echo "WARNING: Minimum 15GB disk space recommended (found ${DISK}GB available)"
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
    ca-certificates

# Add OpenNebula repository (modern approach - no apt-key deprecation warnings)
echo "--- Adding OpenNebula Repository ---"
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list

sudo apt update

# Install OpenNebula Frontend (includes web interface)
echo "--- Installing OpenNebula Frontend ---"
sudo apt install -y \
    opennebula \
    opennebula-sunstone \
    opennebula-gate \
    opennebula-flow

# Install Compute Node components (to make Device 1 also a compute node)
echo "--- Installing Compute Node Components ---"
sudo apt install -y \
    opennebula-node \
    opennebula-rubygems

# Enable and start services
echo "--- Enabling and Starting Services ---"
sudo systemctl enable opennebula opennebula-sunstone opennebula-gate opennebula-flow
sudo systemctl start opennebula opennebula-sunstone opennebula-gate opennebula-flow

# Wait for services to start
echo "--- Waiting for services to initialize ---"
sleep 10

# Configure oneadmin user SSH key
echo "--- Configuring oneadmin SSH Key ---"
sudo -u oneadmin ssh-keygen -t rsa -N "" -f /var/lib/one/.ssh/id_rsa

# Set proper permissions
sudo -u oneadmin chmod 700 /var/lib/one/.ssh
sudo -u oneadmin chmod 600 /var/lib/one/.ssh/id_rsa
sudo -u oneadmin chmod 644 /var/lib/one/.ssh/id_rsa.pub

# Check service status
echo "--- Service Status Check ---"
sudo systemctl status opennebula --no-pager -l
sudo systemctl status opennebula-sunstone --no-pager -l

# Get access information
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
ONE_AUTH=$(sudo cat /var/lib/one/.one/one_auth 2>/dev/null || echo "Not available yet")

echo ""
echo "=== OpenNebula Installation Complete ==="
echo ""
echo "📊 System Info:"
echo "  - RAM: ${RAM}GB"
echo "  - Available Disk: ${DISK}GB"
echo "  - Host IP: $HOST_IP"
echo ""
echo "🌐 Access Information:"
echo "  - Web Interface: http://$HOST_IP:9869"
echo "  - Username: oneadmin"
echo "  - Password: $ONE_AUTH"
echo ""
echo "🔧 Next Steps:"
echo "  1. Access web interface at http://$HOST_IP:9869"
echo "  2. Add compute nodes using: sudo -u oneadmin onehost create HOSTNAME -i kvm -v kvm"
echo "  3. Check nodes with: sudo -u oneadmin onehost list"
echo ""
echo "📋 SSH Public Key (copy to compute nodes):"
echo "$(sudo cat /var/lib/one/.ssh/id_rsa.pub 2>/dev/null || echo 'SSH key not generated yet')"
echo ""

# Create helper script for common commands
cat > ~/opennebula-commands.sh << 'EOF'
#!/bin/bash
# OpenNebula Helper Commands

echo "=== OpenNebula Management Commands ==="
echo ""
echo "Service Management:"
echo "  sudo systemctl status opennebula"
echo "  sudo systemctl restart opennebula-sunstone"
echo ""
echo "Host Management:"
echo "  sudo -u oneadmin onehost list"
echo "  sudo -u oneadmin onehost create HOSTNAME -i kvm -v kvm"
echo ""
echo "VM Management:"
echo "  sudo -u oneadmin onevm list"
echo "  sudo -u oneadmin oneimage list"
echo ""
echo "Web Access:"
echo "  http://$(ip route get 8.8.8.8 | awk '{print $7; exit}'):9869"
echo "  Username: oneadmin"
echo "  Password: $(sudo cat /var/lib/one/.one/one_auth 2>/dev/null)"
EOF

chmod +x ~/opennebula-commands.sh

echo "💡 Helper script created: ~/opennebula-commands.sh"