#!/bin/bash

# Complete Private Cloud Deployment for Sentiment Analyzer
# Phase 6: Full Automated Deployment

set -e  # Exit on any error

echo "=== Starting Complete Private Cloud Deployment ==="

# Configuration
NAMESPACE="sentiment-analyzer"
MONITORING_NAMESPACE="monitoring"
PROJECT_DIR="/Users/aritrananda/Shortcuts/Projects/Senti_anlyzr"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    commands=("docker" "kubectl" "helm" "k3s")
    for cmd in "${commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is not installed"
            exit 1
        fi
    done
    
    # Check if K3s is running
    if ! kubectl get nodes &> /dev/null; then
        log_error "Kubernetes cluster is not running"
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Build and push Docker images
build_images() {
    log_info "Building Docker images..."
    
    cd $PROJECT_DIR
    
    # Build API image
    log_info "Building API image..."
    docker build -t sentiment-analyzer/api:latest ./api/
    
    # Build ML Model image
    log_info "Building ML Model image..."
    docker build -t sentiment-analyzer/ml-model:latest ./ml-model/
    
    # Build Frontend image
    log_info "Building Frontend image..."
    docker build -t sentiment-analyzer/frontend:latest -f ./deployment/frontend/Dockerfile ./frontend/
    
    log_success "All images built successfully"
}

# Deploy to Kubernetes
deploy_to_kubernetes() {
    log_info "Deploying to Kubernetes..."
    
    cd $PROJECT_DIR
    
    # Create namespaces
    log_info "Creating namespaces..."
    kubectl apply -f k8s/00-namespace.yaml
    
    # Deploy ConfigMaps and Secrets
    log_info "Deploying configuration..."
    kubectl apply -f k8s/01-configmaps.yaml
    
    # Deploy MongoDB
    log_info "Deploying MongoDB..."
    kubectl apply -f k8s/02-mongodb.yaml
    
    # Wait for MongoDB to be ready
    log_info "Waiting for MongoDB to be ready..."
    kubectl wait --for=condition=ready pod -l app=mongodb -n $NAMESPACE --timeout=300s
    
    # Deploy ML Model Service
    log_info "Deploying ML Model Service..."
    kubectl apply -f k8s/03-ml-model.yaml
    
    # Wait for ML Model to be ready
    log_info "Waiting for ML Model Service to be ready..."
    kubectl wait --for=condition=ready pod -l app=ml-model -n $NAMESPACE --timeout=600s
    
    # Deploy API Service
    log_info "Deploying API Service..."
    kubectl apply -f k8s/04-api.yaml
    
    # Wait for API Service to be ready
    log_info "Waiting for API Service to be ready..."
    kubectl wait --for=condition=ready pod -l app=api-service -n $NAMESPACE --timeout=300s
    
    # Deploy Frontend
    log_info "Deploying Frontend..."
    kubectl apply -f k8s/05-frontend.yaml
    
    # Deploy Ingress
    log_info "Deploying Ingress..."
    kubectl apply -f k8s/06-ingress.yaml
    
    log_success "Core application deployed successfully"
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    cd $PROJECT_DIR
    
    # Deploy Prometheus
    log_info "Deploying Prometheus..."
    kubectl apply -f k8s/monitoring/prometheus.yaml
    
    # Deploy Grafana
    log_info "Deploying Grafana..."
    kubectl apply -f k8s/monitoring/grafana.yaml
    
    # Wait for monitoring services
    log_info "Waiting for monitoring services to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n $MONITORING_NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n $MONITORING_NAMESPACE --timeout=300s
    
    log_success "Monitoring stack deployed successfully"
}

# Setup Istio (optional)
setup_istio() {
    log_info "Setting up Istio Service Mesh (optional)..."
    
    if command -v istioctl &> /dev/null; then
        # Install Istio
        istioctl install --set values.defaultRevision=default -y
        
        # Enable Istio injection
        kubectl label namespace $NAMESPACE istio-injection=enabled
        
        # Apply Istio configurations
        kubectl apply -f k8s/istio-traffic-management.yaml
        
        log_success "Istio Service Mesh configured"
    else
        log_warning "Istio not found, skipping service mesh setup"
    fi
}

# Health checks
health_checks() {
    log_info "Performing health checks..."
    
    # Check if all pods are running
    log_info "Checking pod status..."
    kubectl get pods -n $NAMESPACE
    kubectl get pods -n $MONITORING_NAMESPACE
    
    # Test API endpoints
    log_info "Testing API endpoints..."
    
    # Port forward for testing
    kubectl port-forward -n $NAMESPACE svc/api-service 8000:8000 &
    API_PID=$!
    sleep 5
    
    # Test health endpoint
    if curl -f http://localhost:8000/health; then
        log_success "API health check passed"
    else
        log_error "API health check failed"
    fi
    
    # Clean up port forward
    kill $API_PID 2>/dev/null || true
    
    # Test ML Model
    kubectl port-forward -n $NAMESPACE svc/ml-model-service 8001:8001 &
    ML_PID=$!
    sleep 5
    
    if curl -f http://localhost:8001/health; then
        log_success "ML Model health check passed"
    else
        log_error "ML Model health check failed"
    fi
    
    kill $ML_PID 2>/dev/null || true
}

# Display access information
display_access_info() {
    log_success "Deployment completed successfully!"
    echo ""
    echo "=== ACCESS INFORMATION ==="
    echo ""
    echo "🌐 Application URLs (add to /etc/hosts):"
    echo "   127.0.0.1 sentiment-analyzer.local"
    echo "   127.0.0.1 api.sentiment-analyzer.local"
    echo "   127.0.0.1 ml.sentiment-analyzer.local"
    echo "   127.0.0.1 monitor.sentiment-analyzer.local"
    echo ""
    echo "📊 Monitoring Access:"
    echo "   Grafana: kubectl port-forward -n monitoring svc/grafana-service 3000:3000"
    echo "   Prometheus: kubectl port-forward -n monitoring svc/prometheus-service 9090:9090"
    echo ""
    echo "🔧 Useful Commands:"
    echo "   View logs: kubectl logs -f deployment/api-service -n $NAMESPACE"
    echo "   Scale services: kubectl scale deployment api-service --replicas=5 -n $NAMESPACE"
    echo "   Monitor resources: kubectl top pods -n $NAMESPACE"
    echo ""
    echo "📈 Performance Testing:"
    echo "   Run load test: cd $PROJECT_DIR/cloud-setup && ./03-performance-testing.sh"
    echo ""
    echo "🚀 Your private cloud sentiment analyzer is ready!"
}

# Main deployment flow
main() {
    log_info "Starting deployment process..."
    
    check_prerequisites
    build_images
    deploy_to_kubernetes
    deploy_monitoring
    setup_istio
    
    # Wait for all services to stabilize
    log_info "Waiting for services to stabilize..."
    sleep 30
    
    health_checks
    display_access_info
}

# Run main function
main "$@"
