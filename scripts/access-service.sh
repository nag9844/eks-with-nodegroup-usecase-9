#!/bin/bash

set -e

echo "🌐 Flask Service Access Guide"

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
    echo -e "${BLUE}[ACCESS]${NC} $1"
}

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    print_warning "kubectl is not configured. Please run:"
    echo "aws eks update-kubeconfig --region ap-south-1 --name flask-eks-cluster"
    exit 1
fi

print_status "Checking Flask application status..."

# Check if namespace exists
if ! kubectl get namespace flask-app &> /dev/null; then
    print_warning "flask-app namespace not found. Please deploy the application first."
    exit 1
fi

# Check deployment status
DEPLOYMENT_STATUS=$(kubectl get deployment flask-app -n flask-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED_REPLICAS=$(kubectl get deployment flask-app -n flask-app -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")

print_status "Deployment Status: $DEPLOYMENT_STATUS/$DESIRED_REPLICAS pods ready"

if [ "$DEPLOYMENT_STATUS" != "$DESIRED_REPLICAS" ] || [ "$DEPLOYMENT_STATUS" = "0" ]; then
    print_warning "Application is not fully ready. Current pod status:"
    kubectl get pods -n flask-app
    echo ""
    print_warning "Please wait for all pods to be in Running state before accessing the service."
fi

echo ""
print_status "🚀 Available Access Methods:"
echo ""

# Method 1: Port Forward (Always works)
print_info "1. LOCAL ACCESS (Port Forward) - Recommended for testing"
echo "   Run this command in a separate terminal:"
echo "   kubectl port-forward -n flask-app svc/flask-app-service 8080:80"
echo ""
echo "   Then access in browser:"
echo "   🌐 Main App: http://localhost:8080"
echo "   ❤️  Health Check: http://localhost:8080/health"
echo "   👥 API Users: http://localhost:8080/api/users"
echo "   📊 Metrics: http://localhost:8080/metrics"
echo ""

# Method 2: NodePort (If available)
NODEPORT=$(kubectl get service flask-app-nodeport -n flask-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
if [ ! -z "$NODEPORT" ]; then
    print_info "2. NODEPORT ACCESS"
    echo "   Get any worker node IP:"
    echo "   kubectl get nodes -o wide"
    echo ""
    echo "   Then access using: http://<NODE-IP>:$NODEPORT"
    echo ""
fi

# Method 3: Load Balancer (If ingress is configured)
print_info "3. LOAD BALANCER ACCESS (Internet-facing)"
LB_URL=$(kubectl get ingress flask-app-ingress -n flask-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ ! -z "$LB_URL" ]; then
    print_status "✅ Load Balancer is ready!"
    echo "   🌐 HTTP: http://$LB_URL"
    echo "   🔒 HTTPS: https://$LB_URL"
    echo ""
    echo "   Available endpoints:"
    echo "   • Main App: http://$LB_URL/"
    echo "   • Health Check: http://$LB_URL/health"
    echo "   • API Users: http://$LB_URL/api/users"
    echo "   • Metrics: http://$LB_URL/metrics"
else
    print_warning "Load Balancer not ready yet. Checking ingress status..."
    kubectl get ingress flask-app-ingress -n flask-app 2>/dev/null || echo "Ingress not found"
    echo ""
    print_info "To enable Load Balancer access:"
    echo "   1. Ensure AWS Load Balancer Controller is installed"
    echo "   2. Apply the ingress configuration: kubectl apply -f k8s/ingress.yaml"
    echo "   3. Wait 2-3 minutes for AWS ALB to be provisioned"
fi

echo ""
print_status "🔧 Quick Test Commands:"
echo ""

# If port-forward is running, test it
if curl -s http://localhost:8080/health &> /dev/null; then
    print_status "✅ Local port-forward is active and working!"
    echo "   Test: curl http://localhost:8080/health"
else
    echo "   Start port-forward: kubectl port-forward -n flask-app svc/flask-app-service 8080:80 &"
    echo "   Test: curl http://localhost:8080/health"
fi

# If load balancer is available, test it
if [ ! -z "$LB_URL" ]; then
    echo "   Test Load Balancer: curl http://$LB_URL/health"
fi

echo ""
print_status "📋 Service Information:"
kubectl get services -n flask-app
echo ""

print_status "🏷️  Pod Information:"
kubectl get pods -n flask-app -o wide

echo ""
print_status "📝 To view application logs:"
echo "kubectl logs -f deployment/flask-app -n flask-app"