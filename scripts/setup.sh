#!/bin/bash

set -e

echo "🚀 Setting up DevOps Challenge Environment"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    print_status "All prerequisites are installed ✅"
}

# Setup AWS credentials
setup_aws() {
    print_status "Checking AWS credentials..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region)
    
    print_status "AWS Account ID: $ACCOUNT_ID"
    print_status "AWS Region: $REGION"
}

# Create S3 bucket for Terraform state
create_terraform_backend() {
    print_status "Setting up Terraform backend..."
    
    BUCKET_NAME="terraform-state-$(openssl rand -hex 4)"
    
    # Create S3 bucket
    if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
        aws s3 mb "s3://$BUCKET_NAME" --region $REGION
        print_status "Created S3 bucket: $BUCKET_NAME"
    else
        print_warning "S3 bucket $BUCKET_NAME already exists"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket $BUCKET_NAME \
        --versioning-configuration Status=Enabled
    
    # Create DynamoDB table for state locking
    if ! aws dynamodb describe-table --table-name terraform-state-lock --region $REGION &> /dev/null; then
        aws dynamodb create-table \
            --table-name terraform-state-lock \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
            --region $REGION
        print_status "Created DynamoDB table for state locking"
    else
        print_warning "DynamoDB table terraform-state-lock already exists"
    fi
    
    # Update backend configuration
    sed -i.bak "s/your-terraform-state-bucket/$BUCKET_NAME/g" terraform/backend.tf
    sed -i.bak "s/us-west-2/$REGION/g" terraform/backend.tf
    
    print_status "Updated Terraform backend configuration"
}

# Initialize and apply Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Plan deployment
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
    print_status "Configuring kubectl..."
    
    CLUSTER_NAME=$(cd terraform && terraform output -raw cluster_name)
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
    
    print_status "kubectl configured for cluster: $CLUSTER_NAME"
}

# Build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)
    
    # Login to ECR
    aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL
    
    # Build image
    docker build -t flask-microservice -f docker/Dockerfile .
    
    # Tag and push image
    docker tag flask-microservice:latest $ECR_URL:latest
    docker push $ECR_URL:latest
    
    print_status "Docker image pushed to ECR: $ECR_URL:latest"
}

# Deploy application to Kubernetes
deploy_application() {
    print_status "Deploying application to Kubernetes..."
    
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

# Setup monitoring
setup_monitoring() {
    print_status "Setting up monitoring..."
    
    # Apply monitoring manifests
    kubectl apply -f monitoring/prometheus-config.yaml
    kubectl apply -f monitoring/prometheus.yaml
    kubectl apply -f monitoring/grafana.yaml
    
    print_status "Monitoring setup complete!"
    print_status "Prometheus: kubectl port-forward -n monitoring svc/prometheus-service 9090:8080"
    print_status "Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000"
}

# Main execution
main() {
    print_status "Starting DevOps Challenge Setup"
    
    check_prerequisites
    setup_aws
    create_terraform_backend
    deploy_infrastructure
    configure_kubectl
    build_and_push_image
    deploy_application
    setup_monitoring
    
    print_status "🎉 Setup completed successfully!"
    print_status ""
    print_status "Next steps:"
    print_status "1. Check your application: kubectl get pods -n flask-app"
    print_status "2. Access via port-forward: kubectl port-forward -n flask-app svc/flask-app-service 8080:80"
    print_status "3. Test: curl http://localhost:8080/health"
    print_status "4. Setup GitHub Actions with your AWS credentials"
}

# Run main function
main "$@"