#!/bin/bash

# DevStack Installation Script for OpenStack Private Cloud
# This script installs OpenStack using DevStack

echo "=== DevStack Installation for OpenStack Private Cloud ==="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script as root. Run as stack user or regular user."
    exit 1
fi

# Detect network interface and IP
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
HOST_IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -1)

echo "--- Network Configuration ---"
echo "Primary Interface: $INTERFACE"
echo "Host IP: $HOST_IP"

# Update local.conf with detected IP
sudo -u stack sed -i "s/HOST_IP=.*/HOST_IP=$HOST_IP/" /opt/stack/devstack/local.conf

# Create volume group for Cinder (block storage)
echo "--- Setting up Cinder Storage ---"
sudo losetup /dev/loop0 || true
if [ ! -f /opt/stack/data/stack-volumes-lvmdriver-1.img ]; then
    sudo mkdir -p /opt/stack/data
    sudo dd if=/dev/zero of=/opt/stack/data/stack-volumes-lvmdriver-1.img bs=1G count=20
    sudo losetup /dev/loop0 /opt/stack/data/stack-volumes-lvmdriver-1.img
    sudo pvcreate /dev/loop0
    sudo vgcreate stack-volumes /dev/loop0
fi

# Install DevStack
echo "--- Starting DevStack Installation ---"
echo "This will take 30-60 minutes depending on your internet speed..."

cd /opt/stack/devstack
sudo -u stack ./stack.sh

# Check installation status
if [ $? -eq 0 ]; then
    echo "=== DevStack Installation Successful ==="
    echo ""
    echo "OpenStack Dashboard (Horizon): http://$HOST_IP/dashboard"
    echo "Username: admin or demo"
    echo "Password: admin123"
    echo ""
    echo "OpenStack CLI environment:"
    echo "source /opt/stack/devstack/openrc admin admin"
    echo ""
    echo "Verify installation:"
    echo "openstack service list"
    echo "openstack network list"
    echo "openstack flavor list"
else
    echo "=== DevStack Installation Failed ==="
    echo "Check logs at: /opt/stack/logs/stack.sh.log"
    exit 1
fi

# Create OpenStack CLI environment file
tee ~/openstack-admin.sh << EOF
#!/bin/bash
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=admin123
export OS_AUTH_URL=http://$HOST_IP/identity
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_VOLUME_API_VERSION=3
export OS_INTERFACE=public
EOF

chmod +x ~/openstack-admin.sh

echo "=== Post-Installation Setup ==="
echo "Source OpenStack environment: source ~/openstack-admin.sh"
echo "Or use DevStack's: source /opt/stack/devstack/openrc admin admin"