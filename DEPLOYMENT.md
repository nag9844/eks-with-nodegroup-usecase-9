# Deployment Guide - ingress-nginx Setup

This guide provides step-by-step instructions for deploying the Flask microservice to Amazon EKS using ingress-nginx controller.

## Prerequisites

Before starting, ensure you have the following tools installed:

- [AWS CLI](https://aws.amazon.com/cli/) (v2.0+)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (v1.28+)
- [Terraform](https://www.terraform.io/downloads.html) (v1.5+)
- [Docker](https://docs.docker.com/get-docker/) (v20.0+)
- [Helm](https://helm.sh/docs/intro/install/) (v3.0+)

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Clone the repository
git clone <your-repo-url>
cd devops-challenge

# Make setup script executable and run
chmod +x scripts/deploy-with-nginx.sh
./scripts/deploy-with-nginx.sh
```

### Option 2: Manual Setup

Follow the detailed steps below for manual deployment.

## Manual Deployment Steps

### 1. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 2. Setup Terraform Backend

Create an S3 bucket for Terraform state storage:

```bash
# Create a unique bucket name
BUCKET_NAME="terraform-state-$(openssl rand -hex 4)"
REGION="us-west-2"

# Create S3 bucket
aws s3 mb s3://$BUCKET_NAME --region $REGION

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $BUCKET_NAME \
    --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1 \
    --region $REGION
```

Update `terraform/backend.tf` with your bucket name:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-bucket-name-here"  # Replace with your bucket name
    key            = "eks-flask-app/terraform.tfstate"
    region         = "us-west-2"              # Replace with your region
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### 3. Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

This will create:
- VPC with public/private subnets
- EKS cluster
- ECR repository
- ingress-nginx controller with NLB

### 4. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name flask-eks-cluster

# Verify connection
kubectl get nodes
```

### 5. Build and Push Docker Image

```bash
# Get ECR repository URL
ECR_URL=$(cd terraform && terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_URL

# Build and push image
docker build -t flask-microservice -f docker/Dockerfile .
docker tag flask-microservice:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### 6. Deploy Application

```bash
# Update deployment with ECR URL
sed -i "s|ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/flask-microservice-app:latest|$ECR_URL:latest|g" k8s/deployment.yaml

# Deploy to Kubernetes
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml

# Wait for deployment
kubectl rollout status deployment/flask-app -n flask-app

# Deploy ingress
kubectl apply -f k8s/ingress-nginx.yaml
```

### 7. Get Load Balancer URL

```bash
# Get the load balancer hostname
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Or use the helper script
./scripts/get-nginx-url.sh
```

## Accessing the Application

### External Access (Load Balancer)

```bash
# Get load balancer URL
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Access endpoints
curl http://$LB_URL/health
curl http://$LB_URL/
curl http://$LB_URL/api/users
```

### Local Access (Port Forward)

```bash
# Access the application locally
kubectl port-forward -n flask-app svc/flask-app-service 8080:80

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/
curl http://localhost:8080/api/users
```

## Monitoring Setup (Optional)

```bash
# Deploy Prometheus and Grafana
kubectl apply -f monitoring/prometheus-config.yaml
kubectl apply -f monitoring/prometheus.yaml
kubectl apply -f monitoring/grafana.yaml

# Access monitoring
kubectl port-forward -n monitoring svc/prometheus-service 9090:8080  # Prometheus
kubectl port-forward -n monitoring svc/grafana 3000:3000             # Grafana (admin/admin123)
```

## CI/CD Setup

### GitHub Actions Setup

1. Add the following secrets to your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. The workflows will automatically:
   - Run Terraform validation on PRs
   - Deploy infrastructure on main branch
   - Build and deploy application on code changes

### Manual Trigger

```bash
# Trigger deployment manually
git add .
git commit -m "Deploy application with ingress-nginx"
git push origin main
```

## Verification

### Check Application Health

```bash
# Check pods
kubectl get pods -n flask-app

# Check services
kubectl get svc -n flask-app

# Check ingress
kubectl get ingress -n flask-app

# Check ingress-nginx controller
kubectl get svc -n ingress-nginx

# View logs
kubectl logs -n flask-app deployment/flask-app
```

### Test API Endpoints

```bash
# Get load balancer URL
LB_URL=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://$LB_URL/health

# Get users
curl http://$LB_URL/api/users

# Create user
curl -X POST http://$LB_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'
```

## Troubleshooting

### Common Issues

1. **Load Balancer Not Ready**
   ```bash
   kubectl get svc -n ingress-nginx
   # Wait for EXTERNAL-IP to show hostname (takes 2-3 minutes)
   ```

2. **Application Not Responding**
   ```bash
   kubectl get pods -n flask-app
   kubectl describe pod -n flask-app <pod-name>
   kubectl logs -n flask-app <pod-name>
   ```

3. **ingress-nginx Controller Issues**
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
   ```

### Useful Commands

```bash
# View all resources
kubectl get all -n flask-app

# Check cluster info
kubectl cluster-info

# View Terraform outputs
cd terraform && terraform output

# Check AWS resources
aws eks describe-cluster --name flask-eks-cluster
aws ecr describe-repositories
```

## Cleanup

To destroy all resources:

```bash
# Automated cleanup
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh

# Manual cleanup
kubectl delete namespace flask-app monitoring
cd terraform && terraform destroy
```

## Architecture Benefits

### ingress-nginx Advantages
- **Cost Effective**: Single NLB instead of multiple ALBs
- **Portable**: Works on any Kubernetes cluster
- **Feature Rich**: SSL termination, rate limiting, metrics
- **Simple**: No complex IAM/OIDC setup required
- **Reliable**: Battle-tested in production

### Security Features
- Private subnets for worker nodes
- IAM roles with least privilege
- Security groups with minimal access
- ECR image scanning
- EKS encryption at rest

This setup provides a production-ready, cost-effective solution for deploying Flask microservices on EKS.