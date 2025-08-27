#!/bin/bash

# Istio Service Mesh Setup for Advanced Load Balancing
# Phase 4A: Service Mesh Installation and Configuration

echo "=== Installing Istio Service Mesh ==="

# 1. Install Istio
istioctl install --set values.defaultRevision=default -y

# 2. Enable Istio injection for sentiment-analyzer namespace
kubectl label namespace sentiment-analyzer istio-injection=enabled

# 3. Verify installation
kubectl get pods -n istio-system

echo "=== Istio Installation Complete ==="

# 4. Install Istio addons for observability
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/addons/jaeger.yaml

echo "=== Istio Service Mesh Setup Complete ==="
echo "Access Kiali: kubectl port-forward -n istio-system svc/kiali 20001:20001"
echo "Access Jaeger: kubectl port-forward -n istio-system svc/jaeger 16686:16686"
