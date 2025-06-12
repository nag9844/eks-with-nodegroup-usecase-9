#!/bin/bash

set -e

echo "🌐 Getting ingress-nginx Load Balancer URL"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[URL]${NC} $1"
}

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    print_warning "kubectl is not configured. Please run:"
    echo "aws eks update-kubeconfig --region ap-south-1 --name flask-eks-cluster"
    exit 1
fi

print_status "Checking ingress-nginx controller status..."

# Check if ingress-nginx namespace exists
if ! kubectl get namespace ingress-nginx &> /dev/null; then
    print_warning "ingress-nginx namespace not found. Please deploy the infrastructure first."
    exit 1
fi

# Check if controller is running
CONTROLLER_STATUS=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED_REPLICAS=$(kubectl get deployment ingress-nginx-controller -n ingress-nginx -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

print_status "Controller Status: $CONTROLLER_STATUS/$DESIRED_REPLICAS replicas ready"

if [ "$CONTROLLER_STATUS" != "$DESIRED_REPLICAS" ] || [ "$CONTROLLER_STATUS" = "0" ]; then
    print_warning "ingress-nginx controller is not ready. Current status:"
    kubectl get pods -n ingress-nginx
    echo ""
    print_warning "Please wait for the controller to be ready before accessing the service."
fi

# Get Load Balancer URL
print_status "Getting Load Balancer information..."

LB_HOSTNAME=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ ! -z "$LB_HOSTNAME" ]; then
    print_status "✅ Load Balancer is ready!"
    echo ""
    print_info "🌐 Application URLs:"
    echo "   Main App: http://$LB_HOSTNAME"
    echo "   Health Check: http://$LB_HOSTNAME/health"
    echo "   API Users: http://$LB_HOSTNAME/api/users"
    echo "   Metrics: http://$LB_HOSTNAME/metrics"
    echo ""
    
    # Test connectivity
    print_status "Testing connectivity..."
    if curl -s --connect-timeout 10 "http://$LB_HOSTNAME/health" &> /dev/null; then
        print_status "✅ Application is responding!"
    else
        print_warning "Load Balancer ready but application not responding yet."
        print_warning "This is normal for new deployments. Try again in a few minutes."
    fi
else
    print_warning "Load Balancer not ready yet."
    
    # Check service status
    print_status "Service status:"
    kubectl get service ingress-nginx-controller -n ingress-nginx
    
    print_warning "If the EXTERNAL-IP shows <pending>, wait a few minutes for AWS to provision the NLB."
fi

echo ""
print_status "🔧 Alternative Access Methods:"
echo ""

# Port Forward method
print_info "1. PORT FORWARD (Always works):"
echo "   kubectl port-forward -n flask-app svc/flask-app-service 8080:80"
echo "   Then access: http://localhost:8080"
echo ""

# NodePort method
NODEPORT=$(kubectl get service flask-app-nodeport -n flask-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
print_info "2. NODEPORT ACCESS:"
echo "   Get node IP: kubectl get nodes -o wide"
echo "   Access via: http://<NODE-IP>:$NODEPORT"

echo ""
print_status "📋 Useful Commands:"
echo "• Check Load Balancer: kubectl get svc -n ingress-nginx"
echo "• Check Ingress: kubectl get ingress -n flask-app"
echo "• Check Pods: kubectl get pods -n flask-app"
echo "• View Logs: kubectl logs -f deployment/flask-app -n flask-app"