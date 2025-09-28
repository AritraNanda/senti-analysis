#!/bin/bash

# OpenNebula Frontend + Compute Node Installation Script
# Updated for Ubuntu 22.04+ with modern GPG keyring approach
# Handles missing commands and provides better error checking

echo "=== OpenNebula Frontend + Compute Node Installation ==="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root. Run as a regular user with sudo privileges."
    exit 1
fi

# Check system requirements
echo "--- System Requirements Check ---"
RAM=$(free -g | grep '^Mem:' | awk '{print $2}')
DISK=$(df -h / | tail -1 | awk '{print $4}' | sed 's/G//')

echo "System Info: ${RAM}GB RAM, ${DISK}GB available disk"

if [ "$RAM" -lt 4 ]; then
    echo "WARNING: Minimum 4GB RAM recommended for OpenNebula (found ${RAM}GB)"
fi

if [ "$DISK" -lt 15 ]; then
    echo "WARNING: Minimum 15GB disk space recommended (found ${DISK}GB available)"
fi

# Prerequisites - install essential tools first
echo "--- Installing Prerequisites ---"
sudo apt update

# Install core utilities first (including tee if missing)
sudo apt install -y \
    coreutils \
    util-linux \
    curl \
    wget \
    gnupg \
    ca-certificates \
    lsb-release

# Install development tools
sudo apt install -y \
    ruby \
    ruby-dev \
    make \
    gcc \
    g++ \
    sqlite3 \
    libsqlite3-dev \
    build-essential

# Check if tee command exists now
if ! command -v tee &> /dev/null; then
    echo "ERROR: tee command still not found after installing coreutils"
    exit 1
fi

# Add OpenNebula repository (modern approach - no apt-key deprecation warnings)
echo "--- Adding OpenNebula Repository ---"

# Download and add GPG key
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg

# Check if GPG key was created successfully
if [ ! -f /usr/share/keyrings/opennebula-archive-keyring.gpg ]; then
    echo "ERROR: Failed to create OpenNebula GPG keyring"
    exit 1
fi

# Add repository using modern signed-by approach
echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list > /dev/null

# Verify repository file was created
if [ ! -f /etc/apt/sources.list.d/opennebula.list ]; then
    echo "ERROR: Failed to create OpenNebula repository file"
    echo "Trying alternative method..."
    
    # Alternative method using cat and redirection
    sudo bash -c 'cat > /etc/apt/sources.list.d/opennebula.list << EOF
deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula
EOF'
fi

# Update package lists
echo "--- Updating Package Lists ---"
sudo apt update

# Verify OpenNebula packages are available
if ! apt-cache search opennebula | grep -q "opennebula "; then
    echo "ERROR: OpenNebula packages not found. Repository setup failed."
    echo "Repository content:"
    cat /etc/apt/sources.list.d/opennebula.list
    exit 1
fi

# Install OpenNebula Frontend (includes web interface)
echo "--- Installing OpenNebula Frontend ---"
sudo apt install -y \
    opennebula \
    opennebula-sunstone \
    opennebula-gate \
    opennebula-flow

# Check if frontend installation succeeded
if ! dpkg -l | grep -q opennebula-sunstone; then
    echo "ERROR: OpenNebula frontend installation failed"
    exit 1
fi

# Install Compute Node components (to make Device 1 also a compute node)
echo "--- Installing Compute Node Components ---"
sudo apt install -y \
    opennebula-node \
    opennebula-rubygems

# Install virtualization components
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils

# Add current user to libvirt group
sudo usermod -a -G libvirt $USER

# Enable and start services
echo "--- Enabling and Starting Services ---"
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

sudo systemctl enable opennebula
sudo systemctl enable opennebula-sunstone  
sudo systemctl enable opennebula-gate
sudo systemctl enable opennebula-flow

sudo systemctl start opennebula
sudo systemctl start opennebula-sunstone
sudo systemctl start opennebula-gate
sudo systemctl start opennebula-flow

# Wait for services to start
echo "--- Waiting for services to initialize ---"
sleep 15

# Check if oneadmin user exists (should be created by opennebula package)
if ! id "oneadmin" &>/dev/null; then
    echo "ERROR: oneadmin user not found. OpenNebula installation may have failed."
    exit 1
fi

# Configure oneadmin user SSH key
echo "--- Configuring oneadmin SSH Key ---"

# Create SSH directory if it doesn't exist
sudo -u oneadmin mkdir -p /var/lib/one/.ssh

# Generate SSH key pair
sudo -u oneadmin ssh-keygen -t rsa -N "" -f /var/lib/one/.ssh/id_rsa

# Set proper permissions
sudo -u oneadmin chmod 700 /var/lib/one/.ssh
sudo -u oneadmin chmod 600 /var/lib/one/.ssh/id_rsa
sudo -u oneadmin chmod 644 /var/lib/one/.ssh/id_rsa.pub

# Check service status
echo "--- Service Status Check ---"
services=("opennebula" "opennebula-sunstone" "opennebula-gate" "opennebula-flow" "libvirtd")

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Not running"
        sudo systemctl status $service --no-pager -l
    fi
done

# Get access information
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null || echo "Could not determine IP")
ONE_AUTH=""

# Wait for oneadmin auth file to be created
echo "--- Waiting for OpenNebula to initialize ---"
for i in {1..30}; do
    if [ -f /var/lib/one/.one/one_auth ]; then
        ONE_AUTH=$(sudo cat /var/lib/one/.one/one_auth)
        break
    fi
    echo "Waiting for OpenNebula initialization... ($i/30)"
    sleep 2
done

if [ -z "$ONE_AUTH" ]; then
    echo "WARNING: OpenNebula auth file not found. Services may still be starting."
    ONE_AUTH="Check /var/lib/one/.one/one_auth after services fully start"
fi

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
if [ -f /var/lib/one/.ssh/id_rsa.pub ]; then
    echo "$(sudo cat /var/lib/one/.ssh/id_rsa.pub)"
else
    echo "SSH key not found - check SSH key generation"
fi
echo ""

# Create management helper script
cat > ~/opennebula-manage.sh << 'EOF'
#!/bin/bash
# OpenNebula Management Helper

echo "=== OpenNebula Management Commands ==="
echo ""
echo "🔧 Service Management:"
echo "  sudo systemctl status opennebula"
echo "  sudo systemctl restart opennebula-sunstone" 
echo "  sudo systemctl restart opennebula"
echo ""
echo "🖥️  Host Management:"
echo "  sudo -u oneadmin onehost list"
echo "  sudo -u oneadmin onehost create HOSTNAME -i kvm -v kvm"
echo "  sudo -u oneadmin onehost show 0"
echo ""
echo "💾 VM Management:"
echo "  sudo -u oneadmin onevm list"
echo "  sudo -u oneadmin oneimage list"
echo "  sudo -u oneadmin onetemplate list"
echo ""
echo "🌐 Web Access:"
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
echo "  http://$HOST_IP:9869"
echo "  Username: oneadmin"
if [ -f /var/lib/one/.one/one_auth ]; then
    echo "  Password: $(sudo cat /var/lib/one/.one/one_auth)"
else
    echo "  Password: Check /var/lib/one/.one/one_auth"
fi
EOF

chmod +x ~/opennebula-manage.sh

echo "💡 Management helper created: ~/opennebula-manage.sh"
echo ""
echo "⚠️  Important Notes:"
echo "  - Log out and back in to activate libvirt group membership"
echo "  - If services fail to start, check logs: sudo journalctl -u opennebula -f"
echo "  - For compute nodes, use the SSH public key shown above"
echo ""
echo "🎉 Installation complete! OpenNebula should be accessible at http://$HOST_IP:9869"