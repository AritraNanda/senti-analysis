# 🚀 Cloud Deployment Roadmap for Sentiment Analyzer
## Lightweight Cloud Solutions for 4GB VMs with Multi-Device Architecture

### **🎯 PROJECT OBJECTIVES (UPDATED FOR LIMITED RESOURCES)**
- **Target Hardware**: 4GB RAM, 20GB storage, 3-core VMs
- **Multi-Device Setup**: Distributed architecture across multiple lightweight VMs
- **Container Orchestration**: K3s, Docker Swarm, or OpenNebula
- **Response Time**: < 2s for 95% of requests
- **Latency**: < 500ms for API calls
- **Throughput**: 50+ concurrent users (optimized for resources)
- **Availability**: 99.5% uptime
- **Scalability**: Horizontal scaling across devices

### **💡 DEPLOYMENT OPTIONS ANALYSIS**

#### **Option 1: OpenNebula Multi-Device ⭐ Recommended for Learning**
- **Use Case**: Enterprise cloud management experience
- **Resource Usage**: 2GB RAM for OpenNebula + 2GB for VMs
- **Architecture**: Frontend + Compute nodes
- **Learning Value**: Full IaaS experience

#### **Option 2: K3s Kubernetes Cluster ⭐⭐ Best for Production**
- **Use Case**: Cloud-native application deployment
- **Resource Usage**: 1GB RAM for K3s + apps
- **Architecture**: Master + Worker nodes
- **Learning Value**: Industry-standard container orchestration

#### **Option 3: Docker Swarm ⭐⭐⭐ Simplest Setup**
- **Use Case**: Simple container orchestration
- **Resource Usage**: 500MB RAM for Swarm + apps
- **Architecture**: Manager + Worker nodes
- **Learning Value**: Container basics with orchestration

### **🏗️ MULTI-DEVICE ARCHITECTURE OPTIONS**

#### **OpenNebula Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Device 1      │    │   Device 2      │    │   Device N      │
│   (4GB/20GB)    │    │   (4GB/20GB)    │    │   (4GB/20GB)    │
│                 │    │                 │    │                 │
│ OpenNebula      │◄──►│ Compute Node    │◄──►│ Compute Node    │
│ Frontend +      │    │ (VMs only)      │    │ (VMs only)      │
│ Compute         │    │                 │    │                 │
│                 │    │                 │    │                 │
│ • Web UI        │    │ • VM Hosting    │    │ • VM Hosting    │
│ • VM Management │    │ • Auto Scale    │    │ • Load Balance  │
│ • Load Balancer │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### **K3s Kubernetes Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Device 1      │    │   Device 2      │    │   Device N      │
│   (4GB/20GB)    │    │   (4GB/20GB)    │    │   (4GB/20GB)    │
│                 │    │                 │    │                 │
│ K3s Master      │◄──►│ K3s Worker      │◄──►│ K3s Worker      │
│ + Worker        │    │                 │    │                 │
│                 │    │                 │    │                 │
│ • API Service   │    │ • ML Model      │    │ • Frontend      │
│ • MongoDB       │    │ • ML Replicas   │    │ • Monitoring    │
│ • Ingress LB    │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### **Docker Swarm Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Device 1      │    │   Device 2      │    │   Device N      │
│   (4GB/20GB)    │    │   (4GB/20GB)    │    │   (4GB/20GB)    │
│                 │    │                 │    │                 │
│ Swarm Manager   │◄──►│ Swarm Worker    │◄──►│ Swarm Worker    │
│ + Worker        │    │                 │    │                 │
│                 │    │                 │    │                 │
│ • API Stack     │    │ • ML Stack      │    │ • Frontend      │
│ • DB Stack      │    │ • Replicas      │    │ • Monitoring    │
│ • Load Balancer │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## **📅 DEPLOYMENT IMPLEMENTATION GUIDE**

### **🚀 OPTION 1: OpenNebula Multi-Device Setup**

#### **Device 1 (Frontend + Compute Node)**
```bash
# Prerequisites
sudo apt update
sudo apt install -y ruby ruby-dev make gcc g++ sqlite3 libsqlite3-dev lsb-release

# Add OpenNebula repository (modern approach)
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list
sudo apt update

# Install OpenNebula Frontend + Compute
sudo apt install -y opennebula opennebula-sunstone opennebula-gate opennebula-flow opennebula-node opennebula-rubygems

# Enable and start services
sudo systemctl enable opennebula opennebula-sunstone opennebula-gate opennebula-flow
sudo systemctl start opennebula opennebula-sunstone opennebula-gate opennebula-flow

# Configure SSH for oneadmin
sudo -u oneadmin ssh-keygen -t rsa -N "" -f /var/lib/one/.ssh/id_rsa
```

#### **Device 2+ (Compute Nodes Only)**
```bash
# Prerequisites
sudo apt update
sudo apt install -y ruby ruby-dev make gcc g++ sqlite3 libsqlite3-dev lsb-release

# Add OpenNebula repository (modern approach)
wget -q -O- https://downloads.opennebula.io/repo/repo2.key | sudo gpg --dearmor -o /usr/share/keyrings/opennebula-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/opennebula-archive-keyring.gpg] https://downloads.opennebula.io/repo/6.8/Ubuntu/22.04 stable opennebula" | sudo tee /etc/apt/sources.list.d/opennebula.list
sudo apt update

# Install ONLY compute node components
sudo apt install -y opennebula-node opennebula-rubygems

# Add oneadmin user and configure SSH
sudo adduser oneadmin
sudo mkdir -p /var/lib/one/.ssh
sudo chown oneadmin:oneadmin /var/lib/one/.ssh

# Copy public key from Device 1 to enable passwordless SSH
# On Device 1: sudo cat /var/lib/one/.ssh/id_rsa.pub
# On Device 2+: echo "PUBLIC_KEY" | sudo tee /var/lib/one/.ssh/authorized_keys
```

#### **Node Registration**
```bash
# On Device 1 (Frontend), register compute nodes:
sudo -u oneadmin onehost create DEVICE2_HOSTNAME -i kvm -v kvm
sudo -u oneadmin onehost create DEVICE3_HOSTNAME -i kvm -v kvm

# Check nodes status
sudo -u oneadmin onehost list

# Access Web Interface: http://DEVICE1_IP:9869
# Username: oneadmin
# Password: sudo cat /var/lib/one/.one/one_auth
```

### **🚀 OPTION 2: K3s Kubernetes Cluster** ⭐⭐ **RECOMMENDED**

#### **Device 1 (K3s Master Node)**
```bash
# Install K3s master
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644

# Wait for node to be ready
sudo k3s kubectl get nodes

# Get join token for worker nodes
sudo cat /var/lib/rancher/k3s/server/node-token

# Get master IP address
ip addr show | grep 'inet ' | grep -v '127.0.0.1'
```

#### **Device 2+ (K3s Worker Nodes)**
```bash
# Join workers to cluster (replace MASTER_IP and TOKEN)
curl -sfL https://get.k3s.io | K3S_URL=https://MASTER_IP:6443 K3S_TOKEN=TOKEN sh -

# Verify node joined (from master)
sudo k3s kubectl get nodes
```

#### **Deploy Sentiment Analyzer**
```bash
# From Device 1 (Master), deploy the application
sudo k3s kubectl apply -f k8s/00-namespace.yaml
sudo k3s kubectl apply -f k8s/01-configmaps.yaml
sudo k3s kubectl apply -f k8s/02-mongodb.yaml
sudo k3s kubectl apply -f k8s/03-ml-model.yaml
sudo k3s kubectl apply -f k8s/04-api.yaml
sudo k3s kubectl apply -f k8s/05-frontend.yaml
sudo k3s kubectl apply -f k8s/06-ingress.yaml

# Check deployment status
sudo k3s kubectl get pods -n sentiment-analyzer
sudo k3s kubectl get svc -n sentiment-analyzer

# Get access URL
sudo k3s kubectl get ingress -n sentiment-analyzer
```

### **🚀 OPTION 3: Docker Swarm** ⭐⭐⭐ **SIMPLEST**

#### **Device 1 (Swarm Manager)**
```bash
# Install Docker
sudo apt update
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
# Log out and back in, or run: newgrp docker

# Initialize Docker Swarm
docker swarm init --advertise-addr $(ip route get 8.8.8.8 | awk '{print $7; exit}')

# Note the join token and command shown
```

#### **Device 2+ (Swarm Workers)**
```bash
# Install Docker
sudo apt update
sudo apt install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in

# Join the swarm (use command from manager output)
docker swarm join --token SWMTKN-1-... MANAGER_IP:2377

# Verify from manager
docker node ls
```

#### **Deploy Sentiment Analyzer Stack**
```bash
# From Device 1 (Manager), deploy using existing docker-compose
docker stack deploy -c docker-compose.yml sentiment-app

# Check services
docker service ls
docker service ps sentiment-app_api
docker service ps sentiment-app_ml-model

# Scale services across nodes
docker service scale sentiment-app_api=3
docker service scale sentiment-app_ml-model=2
```

#### **Day 4: VM Creation and Networking**
```bash
# 1. Create Kubernetes master and worker VMs
# 2. Configure floating IPs
# 3. Setup inter-VM networking
chmod +x cloud-setup/03-vm-creation.sh
./cloud-setup/03-vm-creation.sh
```

#### **Day 5: OpenStack Validation**
```bash
# 1. Test VM connectivity
# 2. Validate storage and networking
# 3. Access Horizon dashboard
# 4. Prepare for Kubernetes installation
```

### **PHASE 2: Kubernetes Cluster Setup on OpenStack (Days 6-10)**
**Objective**: Deploy Kubernetes cluster on OpenStack VMs

#### **Day 6: Kubernetes Master Node Setup**
```bash
# 1. SSH into master VM via OpenStack
# 2. Install Kubernetes control plane
chmod +x cloud-setup/04-k8s-master-setup.sh
./cloud-setup/04-k8s-master-setup.sh

# 3. Initialize cluster
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

#### **Day 7: Worker Nodes Setup**
```bash
# 1. Install Kubernetes on worker VMs
chmod +x cloud-setup/05-k8s-worker-setup.sh
./cloud-setup/05-k8s-worker-setup.sh

# 2. Join workers to cluster
# 3. Install CNI (Flannel/Calico)
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

#### **Day 8: Kubernetes Networking & Storage**
```bash
# 1. Configure Kubernetes networking
# 2. Setup persistent storage with Cinder
# 3. Install MetalLB for LoadBalancer services
kubectl apply -f k8s/metallb-config.yaml
```

#### **Day 9: Namespace and Configuration**
```bash
# 1. Create namespaces
kubectl apply -f k8s/00-namespace.yaml

# 2. Deploy ConfigMaps and Secrets
kubectl apply -f k8s/01-configmaps.yaml

# 3. Verify configurations
kubectl get configmaps -n sentiment-analyzer
kubectl get secrets -n sentiment-analyzer
```

#### **Day 10: Core Services Deployment**
```bash
# 1. Deploy MongoDB with OpenStack Cinder volumes
kubectl apply -f k8s/02-mongodb-openstack.yaml

# 2. Deploy ML Model Service with GPU support
kubectl apply -f k8s/03-ml-model-openstack.yaml

# 3. Deploy API and Frontend services
kubectl apply -f k8s/04-api.yaml
kubectl apply -f k8s/05-frontend.yaml
kubectl apply -f k8s/06-ingress-openstack.yaml
```

### **PHASE 3: Monitoring and Observability (Days 7-9)**
**Objective**: Implement comprehensive monitoring stack

#### **Day 7: Prometheus Setup**
```bash
# 1. Deploy Prometheus for metrics collection
kubectl apply -f k8s/monitoring/prometheus.yaml

# 2. Configure service discovery
# 3. Setup alerting rules
```

#### **Day 8: Grafana Dashboard**
```bash
# 1. Deploy Grafana
kubectl apply -f k8s/monitoring/grafana.yaml

# 2. Import custom dashboards
# 3. Configure data sources
```

#### **Day 9: Observability Integration**
```bash
# 1. Setup log aggregation
# 2. Configure alerting
# 3. Create custom metrics
```

### **PHASE 4: Advanced Load Balancing (Days 10-12)**
**Objective**: Implement Istio service mesh for advanced traffic management

#### **Day 10: Istio Installation**
```bash
# 1. Install Istio service mesh
chmod +x cloud-setup/02-istio-setup.sh
./cloud-setup/02-istio-setup.sh

# 2. Enable sidecar injection
kubectl label namespace sentiment-analyzer istio-injection=enabled
```

#### **Day 11: Traffic Management**
```bash
# 1. Deploy Istio configurations
kubectl apply -f k8s/istio-traffic-management.yaml

# 2. Configure circuit breakers
# 3. Setup rate limiting
```

#### **Day 12: Service Mesh Observability**
```bash
# 1. Deploy Kiali for visualization
# 2. Configure Jaeger for tracing
# 3. Monitor service interactions
```

### **PHASE 5: Performance Optimization (Days 13-15)**
**Objective**: Optimize for cloud AI service requirements

#### **Day 13: Container Optimization**
```bash
# 1. Build optimized Docker images
# 2. Implement health checks
# 3. Resource optimization
```

#### **Day 14: Performance Testing**
```bash
# 1. Setup load testing tools
chmod +x cloud-setup/03-performance-testing.sh
./cloud-setup/03-performance-testing.sh

# 2. Run K6 stress tests
k6 run cloud-setup/stress_test.js

# 3. Analyze performance metrics
```

#### **Day 15: Tuning and Optimization**
```bash
# 1. Auto-scaling configuration
# 2. Resource limits optimization
# 3. Cache implementation
```

### **PHASE 6: Complete Deployment (Days 16-18)**
**Objective**: Automated deployment and production readiness

#### **Day 16: Automated Deployment**
```bash
# 1. Complete deployment script
chmod +x cloud-setup/deploy.sh
./cloud-setup/deploy.sh

# 2. Validation and testing
# 3. Documentation
```

#### **Day 17: Security Hardening**
```bash
# 1. Network policies
# 2. RBAC configuration
# 3. Security scanning
```

#### **Day 18: Production Readiness**
```bash
# 1. Backup strategies
# 2. Disaster recovery
# 3. Monitoring alerts
```

---

## **🛠️ TECHNOLOGY STACK**

### **Infrastructure Layer**
- **Private Cloud**: OpenStack (DevStack)
  - **Compute**: Nova (Virtual Machines)
  - **Storage**: Cinder (Block Storage)
  - **Networking**: Neutron (SDN)
  - **Identity**: Keystone (Authentication)
  - **Dashboard**: Horizon (Web UI)
- **OS**: Ubuntu Server 22.04 LTS (Host + VMs)
- **Container Runtime**: Docker + containerd
- **Orchestration**: Kubernetes (Full cluster on OpenStack VMs)
- **Service Mesh**: Istio
- **Load Balancer**: MetalLB + NGINX Ingress

### **Application Layer**
- **Frontend**: React + Vite + Nginx
- **API Gateway**: FastAPI with async support
- **ML Service**: DistilBERT via Transformers
- **Database**: MongoDB with replication

### **Monitoring & Observability**
- **Metrics**: Prometheus + Grafana
- **Tracing**: Jaeger
- **Visualization**: Kiali
- **Logging**: Kubernetes native + Grafana Loki

### **DevOps & Automation**
- **CI/CD**: GitLab CI or GitHub Actions
- **Infrastructure as Code**: Kubernetes YAML
- **Configuration Management**: ConfigMaps + Secrets
- **Backup**: Velero for Kubernetes

---

## **📊 PERFORMANCE TARGETS**

### **Response Time Objectives**
| Service | Target | Measurement |
|---------|--------|-------------|
| Frontend | < 100ms | First Contentful Paint |
| API Gateway | < 200ms | 95th percentile |
| ML Model | < 2s | AI processing time |
| Database | < 50ms | Query response |

### **Scalability Targets**
| Metric | Target | Implementation |
|--------|--------|----------------|
| Concurrent Users | 100+ | HPA + Load Balancing |
| Request Rate | 50 RPS | Auto-scaling policies |
| CPU Utilization | < 70% | Resource limits |
| Memory Usage | < 80% | Efficient caching |

### **Reliability Targets**
| Metric | Target | Strategy |
|--------|--------|----------|
| Uptime | 99.9% | Multi-replica deployment |
| Error Rate | < 0.1% | Circuit breakers |
| Recovery Time | < 5min | Health checks + restart |
| Data Durability | 99.99% | MongoDB replication |

---

## **🔧 QUICK DEPLOYMENT COMMANDS**

### **OpenNebula Quick Start**
```bash
# Device 1 (Frontend + Compute)
sudo apt install -y opennebula opennebula-sunstone opennebula-gate opennebula-flow opennebula-node opennebula-rubygems
sudo systemctl enable --now opennebula opennebula-sunstone opennebula-gate opennebula-flow

# Device 2+ (Compute Only)  
sudo apt install -y opennebula-node opennebula-rubygems

# Access: http://DEVICE1_IP:9869 (oneadmin / check /var/lib/one/.one/one_auth)
```

### **K3s Quick Start** ⭐ **RECOMMENDED**
```bash
# Device 1 (Master)
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
sudo cat /var/lib/rancher/k3s/server/node-token  # Get token

# Device 2+ (Workers)
curl -sfL https://get.k3s.io | K3S_URL=https://MASTER_IP:6443 K3S_TOKEN=TOKEN sh -

# Deploy app
sudo k3s kubectl apply -f k8s/
```

### **Docker Swarm Quick Start** ⭐⭐⭐ **SIMPLEST**
```bash
# Device 1 (Manager)
docker swarm init --advertise-addr $(ip route get 8.8.8.8 | awk '{print $7; exit}')

# Device 2+ (Workers)
docker swarm join --token TOKEN MANAGER_IP:2377

# Deploy app
docker stack deploy -c docker-compose.yml sentiment-app
```

### **Step-by-Step Deployment**
```bash
# 1. OpenStack Prerequisites
./cloud-setup/00-openstack-prerequisites.sh && sudo reboot

# 2. Install OpenStack (DevStack)
./cloud-setup/01-devstack-install.sh

# 3. Configure OpenStack
./cloud-setup/02-openstack-config.sh

# 4. Create VMs for Kubernetes
./cloud-setup/03-vm-creation.sh

# 5. Setup Kubernetes Master (SSH to master VM)
ssh ubuntu@<master-floating-ip>
./cloud-setup/04-k8s-master-setup.sh

# 6. Setup Worker Nodes (SSH to each worker)
ssh ubuntu@<worker-floating-ip>
./cloud-setup/05-k8s-worker-setup.sh
# Run join command from master

# 7. Deploy applications (from master or local with kubectl)
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-configmaps.yaml
kubectl apply -f k8s/02-mongodb-openstack.yaml
kubectl apply -f k8s/03-ml-model-openstack.yaml
kubectl apply -f k8s/04-api.yaml
kubectl apply -f k8s/05-frontend.yaml
kubectl apply -f k8s/06-ingress-openstack.yaml

# 8. Deploy monitoring
kubectl apply -f k8s/monitoring/

# 9. Performance testing
./cloud-setup/03-performance-testing.sh
```

### **Access URLs & Management**

#### **OpenNebula Access**
```bash
# Web Interface: http://DEVICE1_IP:9869
# Username: oneadmin
# Password: sudo cat /var/lib/one/.one/one_auth

# CLI Commands:
sudo -u oneadmin onehost list          # List compute nodes
sudo -u oneadmin onevm list            # List VMs
sudo -u oneadmin oneimage list         # List images
```

#### **K3s Access**
```bash
# From master node:
sudo k3s kubectl get nodes                    # List cluster nodes
sudo k3s kubectl get pods -A                  # All pods
sudo k3s kubectl get svc -n sentiment-analyzer # Services

# Application URLs (get ingress IP):
sudo k3s kubectl get ingress -n sentiment-analyzer
# Frontend: http://INGRESS_IP/
# API: http://INGRESS_IP/api/docs
```

#### **Docker Swarm Access**
```bash
# From manager node:
docker node ls                              # List swarm nodes
docker service ls                           # List services
docker service ps sentiment-app_api        # Service details

# Application URLs:
docker service inspect sentiment-app_api --format='{{.Endpoint.Ports}}'
# Access via any node IP on published ports
```

#### **Resource Monitoring**
```bash
# System resources on each device:
htop                    # CPU and memory usage
df -h                   # Disk usage
docker stats            # Container resource usage (Docker/K3s)
sudo k3s kubectl top nodes  # K3s node resources
```

---

## **🎓 LEARNING OUTCOMES**

### **Cloud Technologies Mastered**
- ✅ Private cloud infrastructure setup
- ✅ Kubernetes container orchestration
- ✅ Service mesh architecture (Istio)
- ✅ Load balancing strategies
- ✅ Auto-scaling policies
- ✅ Monitoring and observability

### **AI/ML Cloud Integration**
- ✅ ML model serving at scale
- ✅ AI service optimization
- ✅ Performance tuning for ML workloads
- ✅ Resource management for GPU/CPU
- ✅ Model caching strategies

### **DevOps Best Practices**
- ✅ Infrastructure as Code
- ✅ GitOps deployment strategies
- ✅ Security hardening
- ✅ Backup and disaster recovery
- ✅ Performance testing and optimization

---

## **🚀 ADVANCED FEATURES IMPLEMENTED**

### **Load Balancing Approaches**
1. **Layer 4 Load Balancing**: NGINX Ingress
2. **Layer 7 Load Balancing**: Istio Gateway
3. **Client-side Load Balancing**: Service discovery
4. **Geographic Load Balancing**: Multi-zone deployment
5. **Algorithm Options**: Round-robin, Least connections, IP hash

### **AI Service Optimizations**
1. **Model Caching**: Pre-loaded models in containers
2. **Request Batching**: Efficient processing
3. **Circuit Breakers**: Fault tolerance
4. **Rate Limiting**: Resource protection
5. **Auto-scaling**: Dynamic resource allocation

### **Cloud-Native Features**
1. **Health Checks**: Liveness and readiness probes
2. **Graceful Shutdown**: Clean service termination
3. **Configuration Management**: Environment-specific configs
4. **Secret Management**: Secure credential handling
5. **Service Discovery**: Automatic endpoint resolution

---

## **📋 NEXT STEPS FOR PRODUCTION**

### **Security Enhancements**
- Implement OAuth2/OIDC authentication
- Network segmentation with Calico
- Pod security policies
- Image vulnerability scanning
- Secret rotation strategies

### **Scalability Improvements**
- Multi-node Kubernetes cluster
- GPU support for ML workloads
- Distributed caching with Redis
- Database sharding strategies
- CDN integration for global reach

### **Operational Excellence**
- Comprehensive alerting rules
- Automated backup procedures
- Chaos engineering testing
- Capacity planning tools
- Cost optimization strategies

---

**🎉 Congratulations! You now have a production-ready private cloud setup for your sentiment analyzer with enterprise-grade features including load balancing, auto-scaling, monitoring, and AI service optimization.**
