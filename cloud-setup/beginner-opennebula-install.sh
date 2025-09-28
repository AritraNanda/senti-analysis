#!/bin/bash

# 🚀 OpenNebula Installation Script for Beginners
# Complete step-by-step installation with explanations

set -e  # Exit on any error

echo "=========================================="
echo "🚀 OpenNebula Installation for Beginners"
echo "=========================================="
echo ""

# Function to pause and wait for user
pause() {
    read -p "Press Enter to continue..."
    echo ""
}

# Function to check command success
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ Success!"
    else
        echo "❌ Failed! Check the error message above."
        exit 1
    fi
    echo ""
}

echo "This script will install OpenNebula step by step."
echo "We'll explain each step so you understand what's happening."
echo ""
pause

# STEP 1: System Check
echo "📋 STEP 1: Checking your system..."
echo ""

echo "Ubuntu version:"
cat /etc/os-release | grep PRETTY_NAME
echo ""

echo "Available memory:"
free -h | grep Mem
echo ""

echo "Available disk space:"
df -h / | tail -1
echo ""

echo "Current user: $USER"
echo "Checking sudo access..."
if sudo -n true 2>/dev/null; then
    echo "✅ You have sudo access"
else
    echo "🔐 Testing sudo access..."
    sudo whoami > /dev/null
    echo "✅ Sudo access confirmed"
fi
echo ""
pause

# STEP 2: System Update
echo "🔄 STEP 2: Updating system packages..."
echo ""
echo "This downloads the latest package information from Ubuntu's servers."
echo "It's like updating your app store before installing new apps."
echo ""

sudo apt update
check_success

echo "Do you want to upgrade existing packages? This is optional but recommended."
echo "It might take several minutes depending on your system."
read -p "Upgrade now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Upgrading packages..."
    sudo apt upgrade -y
    check_success
else
    echo "Skipping package upgrade."
    echo ""
fi

# STEP 3: Install Essential Tools
echo "🛠️  STEP 3: Installing essential system tools..."
echo ""
echo "Installing core utilities (basic Linux commands):"
echo "- coreutils: Basic commands like 'tee', 'cat', 'ls'"
echo "- curl/wget: Tools to download files from internet"
echo "- gnupg: Security tools for package verification"
echo ""

sudo apt install -y coreutils util-linux curl wget gnupg ca-certificates lsb-release
check_success

echo "Installing development tools needed for OpenNebula:"
echo "- ruby: Programming language (OpenNebula is written in Ruby)"
echo "- gcc/g++/make: Compilers to build software"
echo "- sqlite3: Lightweight database"
echo ""

sudo apt install -y ruby ruby-dev make gcc g++ sqlite3 libsqlite3-dev build-essential
check_success

# STEP 4: Add OpenNebula Repository
echo "🔐 STEP 4: Adding OpenNebula package repository..."
echo ""
echo "We need to tell Ubuntu where to find OpenNebula packages."
echo "First, we'll download OpenNebula's security key to verify packages are authentic."
echo ""

echo "Downloading OpenNebula GPG key..."
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg
check_success

echo "Adding OpenNebula repository to Ubuntu's package sources..."
echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list > /dev/null
check_success

echo "Updating package lists to include OpenNebula packages..."
sudo apt update
check_success

echo "Verifying OpenNebula packages are available..."
if apt search opennebula 2>/dev/null | grep -q "opennebula/"; then
    echo "✅ OpenNebula packages found!"
else
    echo "❌ OpenNebula packages not found. Something went wrong."
    exit 1
fi
echo ""
pause

# STEP 5: Install OpenNebula
echo "📦 STEP 5: Installing OpenNebula packages..."
echo ""
echo "Installing OpenNebula frontend components:"
echo "- opennebula: Core management daemon"
echo "- opennebula-sunstone: Web interface (like a website to manage VMs)"
echo "- opennebula-gate: Service for VM configuration"
echo "- opennebula-flow: Service orchestration tools"
echo ""

sudo apt install -y opennebula opennebula-sunstone opennebula-gate opennebula-flow
check_success

echo "Installing compute node components:"
echo "- opennebula-node: Allows this machine to run virtual machines"
echo "- opennebula-rubygems: Additional Ruby libraries"
echo ""

sudo apt install -y opennebula-node opennebula-rubygems
check_success

echo "Installing virtualization components:"
echo "- qemu-kvm: The actual hypervisor that runs VMs"
echo "- libvirt: Tools to manage virtual machines"
echo "- bridge-utils: Network tools for VMs"
echo ""

sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
check_success

# STEP 6: Configure Services
echo "⚙️  STEP 6: Configuring and starting services..."
echo ""

echo "Starting virtualization services..."
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
check_success

echo "Starting OpenNebula services..."
sudo systemctl enable opennebula opennebula-sunstone opennebula-gate opennebula-flow
sudo systemctl start opennebula opennebula-sunstone opennebula-gate opennebula-flow
check_success

echo "Waiting for services to fully initialize..."
sleep 10

echo "Checking service status..."
services=("opennebula" "opennebula-sunstone" "libvirtd")
all_running=true

for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: Running"
    else
        echo "❌ $service: Not running"
        all_running=false
    fi
done

if [ "$all_running" = false ]; then
    echo ""
    echo "Some services are not running. Let's check the logs:"
    echo "Run this command to see what's wrong: sudo journalctl -u opennebula -n 20"
    exit 1
fi
echo ""
pause

# STEP 7: Configure User Access
echo "👤 STEP 7: Configuring user access..."
echo ""

echo "Adding your user ($USER) to libvirt group for VM management..."
sudo usermod -a -G libvirt $USER
echo "✅ Done! (You'll need to log out and back in later for this to take full effect)"
echo ""

echo "Configuring OpenNebula admin user (oneadmin)..."
echo "Creating SSH key for secure communication..."

# Check if oneadmin user exists
if id "oneadmin" &>/dev/null; then
    echo "✅ oneadmin user exists"
    
    # Create SSH directory
    sudo -u oneadmin mkdir -p /var/lib/one/.ssh
    
    # Generate SSH key if it doesn't exist
    if [ ! -f /var/lib/one/.ssh/id_rsa ]; then
        sudo -u oneadmin ssh-keygen -t rsa -N "" -f /var/lib/one/.ssh/id_rsa
        echo "✅ SSH key generated"
    else
        echo "✅ SSH key already exists"
    fi
    
    # Set proper permissions
    sudo -u oneadmin chmod 700 /var/lib/one/.ssh
    sudo -u oneadmin chmod 600 /var/lib/one/.ssh/id_rsa
    sudo -u oneadmin chmod 644 /var/lib/one/.ssh/id_rsa.pub
    echo "✅ SSH permissions set"
else
    echo "❌ oneadmin user not found. OpenNebula installation may have failed."
    exit 1
fi
echo ""

# STEP 8: Get Access Information
echo "🌐 STEP 8: Getting access information..."
echo ""

echo "Finding your IP address..."
HOST_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(hostname -I | awk '{print $1}')
fi
echo "Your IP address: $HOST_IP"
echo ""

echo "Getting OpenNebula admin password..."
# Wait for auth file to be created
for i in {1..30}; do
    if [ -f /var/lib/one/.one/one_auth ]; then
        break
    fi
    echo "Waiting for OpenNebula to create admin password... ($i/30)"
    sleep 2
done

if [ -f /var/lib/one/.one/one_auth ]; then
    ONE_AUTH=$(sudo cat /var/lib/one/.one/one_auth)
    echo "Admin password: $ONE_AUTH"
else
    echo "⚠️  Admin password not created yet. Services may still be starting."
    echo "Check later with: sudo cat /var/lib/one/.one/one_auth"
    ONE_AUTH="[Check /var/lib/one/.one/one_auth]"
fi
echo ""

# STEP 9: Final Instructions
echo "=========================================="
echo "🎉 Installation Complete!"
echo "=========================================="
echo ""
echo "📊 Your OpenNebula Setup:"
echo "  🌐 Web Interface: http://$HOST_IP:9869"
echo "  👤 Username: oneadmin"
echo "  🔑 Password: $ONE_AUTH"
echo ""
echo "🔍 Next Steps:"
echo "  1. Open your web browser"
echo "  2. Go to: http://$HOST_IP:9869"
echo "  3. Login with username 'oneadmin' and the password above"
echo "  4. Explore the dashboard!"
echo ""
echo "🛠️  Test Commands:"
echo "  sudo -u oneadmin onehost list        # List compute hosts"
echo "  sudo -u oneadmin oneimage list       # List VM images"
echo "  sudo systemctl status opennebula     # Check service status"
echo ""
echo "📚 Help:"
echo "  - If web interface doesn't load, check: sudo systemctl status opennebula-sunstone"
echo "  - View logs with: sudo journalctl -u opennebula -f"
echo "  - For more help, check the BEGINNER_OPENNEBULA_GUIDE.md file"
echo ""

# Create quick access script
cat > ~/opennebula-info.sh << EOF
#!/bin/bash
echo "🌐 OpenNebula Access Information:"
echo "  Web Interface: http://$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null):9869"
echo "  Username: oneadmin"
echo "  Password: \$(sudo cat /var/lib/one/.one/one_auth 2>/dev/null || echo 'Not available')"
echo ""
echo "🔧 Quick Commands:"
echo "  sudo -u oneadmin onehost list"
echo "  sudo -u oneadmin onevm list"
echo "  sudo systemctl status opennebula opennebula-sunstone"
EOF

chmod +x ~/opennebula-info.sh

echo "💡 Created ~/opennebula-info.sh for quick access to login info"
echo ""
echo "Happy cloud computing! 🚀"