#!/bin/bash

# Complete OpenStack + Kubernetes Deployment Script
# Automated deployment of private cloud infrastructure

echo "=== OpenStack + Kubernetes Private Cloud Deployment ==="
echo "This script will deploy a complete private cloud infrastructure"
echo "with sentiment analyzer microservices"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/openstack-deployment.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
set -e
trap 'log "ERROR: Deployment failed at line $LINENO"' ERR

log "Starting private cloud deployment..."

# Phase 1: OpenStack Prerequisites
log "Phase 1: Installing OpenStack prerequisites..."
if [ -f "$SCRIPT_DIR/00-openstack-prerequisites.sh" ]; then
    chmod +x "$SCRIPT_DIR/00-openstack-prerequisites.sh"
    "$SCRIPT_DIR/00-openstack-prerequisites.sh" 2>&1 | tee -a "$LOG_FILE"
    
    log "Prerequisites installed. System reboot required."
    log "After reboot, run: $0 --continue-after-reboot"
    
    if [ "$1" != "--continue-after-reboot" ]; then
        log "Rebooting system in 10 seconds... (Ctrl+C to cancel)"
        sleep 10
        sudo reboot
        exit 0
    fi
else
    log "ERROR: Prerequisites script not found"
    exit 1
fi

# Phase 2: OpenStack Installation
if [ "$1" = "--continue-after-reboot" ]; then
    log "Phase 2: Installing OpenStack (DevStack)..."
    if [ -f "$SCRIPT_DIR/01-devstack-install.sh" ]; then
        chmod +x "$SCRIPT_DIR/01-devstack-install.sh"
        "$SCRIPT_DIR/01-devstack-install.sh" 2>&1 | tee -a "$LOG_FILE"
    else
        log "ERROR: DevStack installation script not found"
        exit 1
    fi

    # Phase 3: OpenStack Configuration
    log "Phase 3: Configuring OpenStack..."
    if [ -f "$SCRIPT_DIR/02-openstack-config.sh" ]; then
        chmod +x "$SCRIPT_DIR/02-openstack-config.sh"
        "$SCRIPT_DIR/02-openstack-config.sh" 2>&1 | tee -a "$LOG_FILE"
    else
        log "ERROR: OpenStack configuration script not found"
        exit 1
    fi

    # Phase 4: VM Creation
    log "Phase 4: Creating Kubernetes VMs..."
    if [ -f "$SCRIPT_DIR/03-vm-creation.sh" ]; then
        chmod +x "$SCRIPT_DIR/03-vm-creation.sh"
        "$SCRIPT_DIR/03-vm-creation.sh" 2>&1 | tee -a "$LOG_FILE"
    else
        log "ERROR: VM creation script not found"
        exit 1
    fi

    # Phase 5: Display next steps
    log "Phase 5: Manual Kubernetes setup required..."
    log ""
    log "=== MANUAL STEPS REQUIRED ==="
    log "1. SSH to master VM and run Kubernetes master setup:"
    if [ -f ~/vm-ips.txt ]; then
        MASTER_IP=$(grep "k8s-master:" ~/vm-ips.txt | cut -d: -f2)
        log "   ssh ubuntu@$MASTER_IP -i ~/.ssh/id_rsa"
    fi
    log "   # Copy setup scripts to VM first:"
    log "   scp -i ~/.ssh/id_rsa cloud-setup/04-k8s-master-setup.sh ubuntu@$MASTER_IP:~/"
    log "   # Then run:"
    log "   ./04-k8s-master-setup.sh"
    log ""
    log "2. SSH to each worker VM and run worker setup:"
    if [ -f ~/vm-ips.txt ]; then
        grep "k8s-worker" ~/vm-ips.txt | while IFS=':' read -r vm_name ip; do
            log "   scp -i ~/.ssh/id_rsa cloud-setup/05-k8s-worker-setup.sh ubuntu@$ip:~/"
            log "   ssh ubuntu@$ip -i ~/.ssh/id_rsa"
            log "   ./05-k8s-worker-setup.sh"
            log "   # Then run the join command from master"
        done
    fi
    log ""
    log "3. Deploy applications (from master or copy kubeconfig):"
    log "   kubectl apply -f k8s/"
    log ""
    log "4. Access applications via LoadBalancer IP"
    log ""
    log "Deployment logs saved to: $LOG_FILE"
fi

# Function to check deployment status
check_status() {
    log "=== Deployment Status Check ==="
    
    # Check OpenStack services
    log "OpenStack Services:"
    if command -v openstack &> /dev/null; then
        source ~/openstack-admin.sh 2>/dev/null || source /opt/stack/devstack/openrc admin admin 2>/dev/null
        openstack service list 2>&1 | tee -a "$LOG_FILE"
    else
        log "OpenStack CLI not available"
    fi
    
    # Check VMs
    log "Virtual Machines:"
    if [ -f ~/vm-ips.txt ]; then
        cat ~/vm-ips.txt | tee -a "$LOG_FILE"
    else
        log "VM IP mapping not found"
    fi
    
    # Check Kubernetes (if accessible)
    log "Kubernetes Status:"
    if command -v kubectl &> /dev/null; then
        kubectl get nodes 2>&1 | tee -a "$LOG_FILE" || log "Kubernetes not accessible from this host"
    else
        log "kubectl not available on this host"
    fi
}

# Copy scripts to VMs function
copy_scripts_to_vms() {
    log "=== Copying setup scripts to VMs ==="
    if [ -f ~/vm-ips.txt ]; then
        while IFS=':' read -r vm_name ip; do
            log "Copying scripts to $vm_name ($ip)..."
            case $vm_name in
                "k8s-master")
                    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa \
                        "$SCRIPT_DIR/04-k8s-master-setup.sh" \
                        ubuntu@$ip:~/
                    ;;
                "k8s-worker-"*)
                    scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa \
                        "$SCRIPT_DIR/05-k8s-worker-setup.sh" \
                        ubuntu@$ip:~/
                    ;;
            esac
        done < ~/vm-ips.txt
        log "Scripts copied to all VMs"
    else
        log "VM IP mapping not found"
    fi
}

# Handle different script arguments
case "$1" in
    "--status")
        check_status
        ;;
    "--continue-after-reboot")
        # Continue deployment after reboot
        ;;
    "--copy-scripts")
        copy_scripts_to_vms
        ;;
    "--help")
        echo "Usage: $0 [OPTIONS]"
        echo "Options:"
        echo "  --continue-after-reboot  Continue deployment after system reboot"
        echo "  --status                 Check deployment status"
        echo "  --copy-scripts           Copy Kubernetes setup scripts to VMs"
        echo "  --help                   Show this help message"
        ;;
    "")
        # Start initial deployment
        ;;
    *)
        log "Unknown option: $1"
        log "Use --help for usage information"
        exit 1
        ;;
esac

log "Deployment script completed. Check logs at: $LOG_FILE"