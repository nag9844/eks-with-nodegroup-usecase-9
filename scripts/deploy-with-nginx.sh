#!/bin/bash

set -e

echo "🚀 Deploying Flask App with ingress-nginx Controller"

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
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        echo "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "Prerequisites check passed ✅"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_info "Deploying infrastructure with ingress-nginx..."
    
    cd terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    print_status "Planning deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Get outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    ECR_URL=$(terraform output -raw ecr_repository_url)
    
    print_status "Infrastructure deployed successfully!"
    print_status "EKS Cluster: $CLUSTER_NAME"
    print_status "ECR Repository: $ECR_URL"
    
    cd ..
}

# Configure kubectl
configure_kubectl() {
    print_info "Configuring kubectl..."
    
    CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
    REGION=$(cd terraform && terraform output -raw region)
    
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    print_status "kubectl configured for cluster: $CLUSTER_NAME"
}

# Build and push Docker image
build_and_push_image() {
    print_info "Building and pushing Docker image..."
    
    ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)
    REGION=$(cd terraform && terraform output -raw region)
    
    # Login to ECR
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL
    
    # Build image
    docker build -t flask-microservice -f docker/Dockerfile .
    
    # Tag and push image
    docker tag flask-microservice:latest $ECR_URL:latest
    docker push $ECR_URL:latest
    
    print_status "Docker image pushed to ECR: $ECR_URL:latest"
}

# Wait for ingress-nginx controller
wait_for_ingress_controller() {
    print_info "Waiting for ingress-nginx controller to be ready..."
    
    # Wait for controller deployment
    kubectl wait --for=condition=available deployment/ingress-nginx-controller -n ingress-nginx --timeout=300s
    
    # Wait for controller service
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s
    
    print_status "ingress-nginx controller is ready ✅"
}

# Deploy application
deploy_application() {
    print_info "Deploying Flask application..."
    
    ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)
    
    # Update deployment with ECR URL
    sed -i.bak "s|ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/flask-microservice-app:latest|$ECR_URL:latest|g" k8s/deployment.yaml
    
    # Apply Kubernetes manifests
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml
    kubectl apply -f k8s/hpa.yaml
    
    # Wait for deployment
    kubectl rollout status deployment/flask-app -n flask-app --timeout=300s
    
    print_status "Application deployed successfully!"
}

# Deploy ingress
deploy_ingress() {
    print_info "Deploying ingress with nginx configuration..."
    
    # Apply the nginx ingress
    kubectl apply -f k8s/ingress-nginx.yaml
    
    print_status "Ingress deployed. Waiting for Load Balancer to be ready..."
    
    # Wait for load balancer to get external IP
    for i in {1..20}; do
        LB_HOSTNAME=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        
        if [ ! -z "$LB_HOSTNAME" ]; then
            print_status "✅ Load Balancer ready: $LB_HOSTNAME"
            
            # Wait for DNS propagation
            print_status "Waiting for DNS propagation..."
            sleep 30
            
            # Test connectivity
            if curl -s --connect-timeout 10 "http://$LB_HOSTNAME/health" &> /dev/null; then
                print_status "🎉 Application is accessible!"
                echo ""
                echo "🌐 Main App: http://$LB_HOSTNAME"
                echo "❤️  Health Check: http://$LB_HOSTNAME/health"
                echo "👥 API Users: http://$LB_HOSTNAME/api/users"
                echo "📊 Metrics: http://$LB_HOSTNAME/metrics"
            else
                print_warning "Load Balancer ready but application not responding yet. May need a few more minutes."
                echo "🌐 Try accessing: http://$LB_HOSTNAME"
            fi
            break
        else
            echo "Waiting for Load Balancer... ($i/20)"
            sleep 15
        fi
    done
    
    if [ -z "$LB_HOSTNAME" ]; then
        print_warning "Load Balancer not ready yet. Check status with:"
        echo "kubectl get service ingress-nginx-controller -n ingress-nginx"
    fi
}

# Provide access information
provide_access_info() {
    print_info "Access Information:"
    
    echo ""
    print_status "🚀 Available Access Methods:"
    
    # Method 1: Load Balancer (if ready)
    LB_HOSTNAME=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ ! -z "$LB_HOSTNAME" ]; then
        echo "1. 🌐 LOAD BALANCER ACCESS (Internet-facing):"
        echo "   Main App: http://$LB_HOSTNAME"
        echo "   Health Check: http://$LB_HOSTNAME/health"
        echo "   API Users: http://$LB_HOSTNAME/api/users"
        echo "   Metrics: http://$LB_HOSTNAME/metrics"
        echo ""
    fi
    
    # Method 2: Port Forward (always works)
    echo "2. 🔗 PORT FORWARD ACCESS (Local testing):"
    echo "   kubectl port-forward -n flask-app svc/flask-app-service 8080:80"
    echo "   Then access: http://localhost:8080"
    echo ""
    
    # Method 3: NodePort
    NODEPORT=$(kubectl get service flask-app-nodeport -n flask-app -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30080")
    echo "3. 🏗️  NODEPORT ACCESS:"
    echo "   Get node IP: kubectl get nodes -o wide"
    echo "   Access via: http://<NODE-IP>:$NODEPORT"
}

# Main execution
main() {
    print_status "Starting deployment with ingress-nginx..."
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    build_and_push_image
    wait_for_ingress_controller
    deploy_application
    deploy_ingress
    provide_access_info
    
    print_status "🎉 Deployment completed successfully!"
    print_status ""
    print_status "📋 Quick Commands:"
    print_status "• Check pods: kubectl get pods -n flask-app"
    print_status "• Check ingress: kubectl get ingress -n flask-app"
    print_status "• Check load balancer: kubectl get svc -n ingress-nginx"
    print_status "• View logs: kubectl logs -f deployment/flask-app -n flask-app"
}

# Run main function
main "$@"