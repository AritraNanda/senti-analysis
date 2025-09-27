#!/bin/bash

# VM Creation Script for Kubernetes Cluster on OpenStack
# Creates master and worker nodes for sentiment analyzer deployment

echo "=== Creating Kubernetes VMs on OpenStack ==="

# Source OpenStack credentials
if [ -f ~/openstack-admin.sh ]; then
    source ~/openstack-admin.sh
elif [ -f /opt/stack/devstack/openrc ]; then
    source /opt/stack/devstack/openrc admin admin
else
    echo "ERROR: OpenStack credentials not found"
    exit 1
fi

# Configuration
INTERNAL_NETWORK="k8s-internal"
PUBLIC_NETWORK="public"
IMAGE="ubuntu-22.04"
KEY_NAME="k8s-keypair"
SECURITY_GROUPS="k8s-cluster,web-services"

# Function to create VM
create_vm() {
    local VM_NAME=$1
    local FLAVOR=$2
    local DESCRIPTION=$3
    
    echo "--- Creating $VM_NAME ($DESCRIPTION) ---"
    
    if openstack server show $VM_NAME >/dev/null 2>&1; then
        echo "$VM_NAME already exists"
        return 0
    fi
    
    # Create VM
    openstack server create \
        --image $IMAGE \
        --flavor $FLAVOR \
        --network $INTERNAL_NETWORK \
        --security-group k8s-cluster \
        --security-group web-services \
        --key-name $KEY_NAME \
        --user-data ~/k8s-cloud-init.yaml \
        $VM_NAME
    
    echo "Waiting for $VM_NAME to be active..."
    openstack server wait --status ACTIVE $VM_NAME --wait 300
    
    if [ $? -eq 0 ]; then
        echo "$VM_NAME created successfully"
    else
        echo "ERROR: Failed to create $VM_NAME"
        return 1
    fi
}

# Function to assign floating IP
assign_floating_ip() {
    local VM_NAME=$1
    
    echo "--- Assigning Floating IP to $VM_NAME ---"
    
    # Create floating IP
    FLOATING_IP=$(openstack floating ip create $PUBLIC_NETWORK -f value -c floating_ip_address)
    
    if [ $? -eq 0 ]; then
        echo "Created floating IP: $FLOATING_IP"
        
        # Assign to VM
        openstack server add floating ip $VM_NAME $FLOATING_IP
        
        if [ $? -eq 0 ]; then
            echo "Assigned $FLOATING_IP to $VM_NAME"
            echo "$VM_NAME:$FLOATING_IP" >> ~/vm-ips.txt
        else
            echo "ERROR: Failed to assign floating IP to $VM_NAME"
        fi
    else
        echo "ERROR: Failed to create floating IP for $VM_NAME"
    fi
}

# Create VMs
echo "--- Creating Kubernetes Cluster VMs ---"

# Create master node
create_vm "k8s-master" "k8s-master" "Kubernetes master node"

# Create worker nodes
create_vm "k8s-worker-1" "k8s-worker" "Kubernetes worker node 1"
create_vm "k8s-worker-2" "k8s-ml-worker" "Kubernetes ML worker node"

# Create storage/monitoring node
create_vm "k8s-storage" "k8s-worker" "Storage and monitoring node"

# Wait a bit for VMs to fully initialize
echo "--- Waiting for VMs to initialize ---"
sleep 30

# Assign floating IPs
echo "--- Assigning Floating IPs ---"
rm -f ~/vm-ips.txt

assign_floating_ip "k8s-master"
assign_floating_ip "k8s-worker-1"
assign_floating_ip "k8s-worker-2"
assign_floating_ip "k8s-storage"

# Display VM information
echo "--- VM Status ---"
openstack server list

echo "--- VM Details with IPs ---"
if [ -f ~/vm-ips.txt ]; then
    echo "VM to Floating IP mapping:"
    cat ~/vm-ips.txt
    echo ""
fi

# Create inventory file for Ansible (optional)
echo "--- Creating Ansible Inventory ---"
tee ~/k8s-inventory << 'EOF'
[k8s-master]
k8s-master ansible_host=MASTER_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-workers]
k8s-worker-1 ansible_host=WORKER1_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
k8s-worker-2 ansible_host=WORKER2_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-storage]
k8s-storage ansible_host=STORAGE_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa

[k8s-cluster:children]
k8s-master
k8s-workers
k8s-storage
EOF

# Replace IPs in inventory file
if [ -f ~/vm-ips.txt ]; then
    while IFS=':' read -r vm_name ip; do
        case $vm_name in
            "k8s-master")
                sed -i "s/MASTER_IP/$ip/" ~/k8s-inventory
                ;;
            "k8s-worker-1")
                sed -i "s/WORKER1_IP/$ip/" ~/k8s-inventory
                ;;
            "k8s-worker-2")
                sed -i "s/WORKER2_IP/$ip/" ~/k8s-inventory
                ;;
            "k8s-storage")
                sed -i "s/STORAGE_IP/$ip/" ~/k8s-inventory
                ;;
        esac
    done < ~/vm-ips.txt
fi

# Test SSH connectivity
echo "--- Testing SSH Connectivity ---"
if [ -f ~/vm-ips.txt ]; then
    while IFS=':' read -r vm_name ip; do
        echo "Testing SSH to $vm_name ($ip)..."
        ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$ip "echo 'SSH to $vm_name successful'" || echo "SSH to $vm_name failed"
    done < ~/vm-ips.txt
fi

echo "=== VM Creation Complete ==="
echo ""
echo "Created VMs:"
echo "- k8s-master: Kubernetes control plane"
echo "- k8s-worker-1: Application workloads"
echo "- k8s-worker-2: ML/AI workloads (high memory)"
echo "- k8s-storage: Database and monitoring"
echo ""
echo "VM IPs saved to: ~/vm-ips.txt"
echo "Ansible inventory: ~/k8s-inventory"
echo ""
echo "Access VMs via SSH:"
echo "ssh ubuntu@<floating-ip> -i ~/.ssh/id_rsa"
echo ""
echo "Next: Setup Kubernetes cluster on these VMs"