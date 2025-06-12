#!/bin/bash

set -e

echo "🧹 Cleaning up DevOps Challenge Environment"

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

# Cleanup Kubernetes resources
cleanup_kubernetes() {
    print_status "Cleaning up Kubernetes resources..."
    
    if kubectl get namespace flask-app &> /dev/null; then
        kubectl delete namespace flask-app --ignore-not-found=true
        print_status "Deleted flask-app namespace"
    fi
    
    if kubectl get namespace monitoring &> /dev/null; then
        kubectl delete namespace monitoring --ignore-not-found=true
        print_status "Deleted monitoring namespace"
    fi
    
    # Clean up AWS Load Balancer Controller if installed
    if kubectl get deployment -n kube-system aws-load-balancer-controller &> /dev/null; then
        helm uninstall aws-load-balancer-controller -n kube-system || true
        print_status "Removed AWS Load Balancer Controller"
    fi
}

# Cleanup ECR images
cleanup_ecr() {
    print_status "Cleaning up ECR images..."
    
    if [ -d "terraform" ] && [ -f "terraform/terraform.tfstate" ]; then
        ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")
        
        if [ ! -z "$ECR_REPO" ]; then
            # Delete all images in the repository
            aws ecr list-images --repository-name $ECR_REPO --query 'imageIds[*]' --output json | \
            jq '.[] | select(.imageTag != null) | {imageTag: .imageTag}' | \
            jq -s '.' | \
            aws ecr batch-delete-image --repository-name $ECR_REPO --image-ids file:///dev/stdin || true
            
            print_status "Cleaned up ECR images"
        fi
    fi
}

# Destroy Terraform infrastructure
destroy_infrastructure() {
    print_status "Destroying Terraform infrastructure..."
    
    if [ -d "terraform" ]; then
        cd terraform
        
        if [ -f "terraform.tfstate" ]; then
            # Destroy infrastructure
            terraform destroy -auto-approve
            print_status "Infrastructure destroyed"
        else
            print_warning "No Terraform state found"
        fi
        
        cd ..
    else
        print_warning "Terraform directory not found"
    fi
}

# Cleanup S3 bucket and DynamoDB table
cleanup_backend() {
    print_status "Cleaning up Terraform backend..."
    
    # Get bucket name from backend.tf if it exists
    if [ -f "terraform/backend.tf" ]; then
        BUCKET_NAME=$(grep -o 'bucket.*=.*"[^"]*"' terraform/backend.tf | cut -d'"' -f2)
        
        if [ ! -z "$BUCKET_NAME" ] && [ "$BUCKET_NAME" != "your-terraform-state-bucket" ]; then
            # Empty and delete S3 bucket
            aws s3 rm s3://$BUCKET_NAME --recursive || true
            aws s3 rb s3://$BUCKET_NAME || true
            print_status "Deleted S3 bucket: $BUCKET_NAME"
        fi
    fi
    
    # Delete DynamoDB table
    aws dynamodb delete-table --table-name terraform-state-lock || true
    print_status "Deleted DynamoDB table: terraform-state-lock"
}

# Cleanup Docker images
cleanup_docker() {
    print_status "Cleaning up local Docker images..."
    
    # Remove flask-microservice images
    docker rmi flask-microservice:latest || true
    docker rmi $(docker images | grep flask-microservice | awk '{print $3}') || true
    
    # Clean up dangling images
    docker image prune -f || true
    
    print_status "Cleaned up Docker images"
}

# Reset configuration files
reset_configs() {
    print_status "Resetting configuration files..."
    
    # Reset backend.tf if backup exists
    if [ -f "terraform/backend.tf.bak" ]; then
        mv terraform/backend.tf.bak terraform/backend.tf
        print_status "Reset terraform/backend.tf"
    fi
    
    # Reset deployment.yaml if backup exists
    if [ -f "k8s/deployment.yaml.bak" ]; then
        mv k8s/deployment.yaml.bak k8s/deployment.yaml
        print_status "Reset k8s/deployment.yaml"
    fi
}

# Main cleanup function
main() {
    print_warning "This will destroy all resources created by the DevOps Challenge setup."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
    
    print_status "Starting cleanup process..."
    
    cleanup_kubernetes
    cleanup_ecr
    destroy_infrastructure
    cleanup_backend
    cleanup_docker
    reset_configs
    
    print_status "🎉 Cleanup completed successfully!"
    print_status ""
    print_status "All resources have been cleaned up."
    print_status "You may need to manually remove any remaining AWS resources if the cleanup was incomplete."
}

# Run main function
main "$@"