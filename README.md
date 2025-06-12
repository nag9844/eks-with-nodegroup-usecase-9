# DevOps Challenge: Flask Microservices on Amazon EKS with ingress-nginx

This repository contains a complete DevOps solution for deploying Flask microservices to Amazon EKS using Infrastructure as Code (Terraform), containerization (Docker), and CI/CD (GitHub Actions) with ingress-nginx controller.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                          AWS Cloud                          │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                        │
│  ├─ Public Subnets (2 AZs)                                │
│  │  ├─ NAT Gateway                                         │
│  │  ├─ Internet Gateway                                    │
│  │  └─ Network Load Balancer (ingress-nginx)              │
│  ├─ Private Subnets (2 AZs)                               │
│  │  └─ EKS Worker Nodes                                    │
│  ├─ EKS Control Plane                                      │
│  ├─ ECR Repository                                         │
│  └─ CloudWatch Logs                                        │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- kubectl installed
- Docker installed
- Terraform >= 1.0
- GitHub repository with Actions enabled

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# Clone and setup
git clone <your-repo-url>
cd devops-challenge

# Deploy with ingress-nginx
chmod +x scripts/deploy-with-nginx.sh
./scripts/deploy-with-nginx.sh
```

### Option 2: Manual Setup

```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 2. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name flask-eks-cluster

# 3. Build and push Docker image
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_URL
docker build -t flask-microservice -f docker/Dockerfile .
docker tag flask-microservice:latest $ECR_URL:latest
docker push $ECR_URL:latest

# 4. Update deployment with ECR URL
sed -i "s|ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/flask-microservice-app:latest|$ECR_URL:latest|g" k8s/deployment.yaml

# 5. Deploy application
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/hpa.yaml
kubectl apply -f k8s/ingress-nginx.yaml

# 6. Get Load Balancer URL
kubectl get svc ingress-nginx-controller -n ingress-nginx
```

## Repository Structure

```
├── terraform/                 # Infrastructure as Code
│   ├── modules/               # Terraform modules
│   │   ├── vpc/              # VPC configuration
│   │   ├── eks/              # EKS cluster with ingress-nginx
│   │   └── ecr/              # Container registry
│   ├── main.tf               # Main configuration
│   └── variables.tf          # Variable definitions
├── docker/                   # Container configurations
│   └── Dockerfile            # Flask app container
├── k8s/                      # Kubernetes manifests
│   ├── deployment.yaml       # Application deployment
│   ├── service.yaml          # Service configuration
│   ├── ingress-nginx.yaml    # ingress-nginx ingress
│   ├── namespace.yaml        # Namespace
│   └── hpa.yaml             # Horizontal Pod Autoscaler
├── .github/workflows/        # CI/CD pipelines
│   ├── terraform.yml         # IaC pipeline
│   └── deploy-nginx.yml      # Application deployment with nginx
├── app/                      # Flask application code
├── monitoring/               # Monitoring configurations
└── scripts/                  # Deployment scripts
    ├── deploy-with-nginx.sh  # Main deployment script
    ├── get-nginx-url.sh      # Get load balancer URL
    ├── access-service.sh     # Service access guide
    ├── setup.sh              # Complete setup
    └── cleanup.sh            # Cleanup resources
```

## Accessing the Application

### 1. Get Load Balancer URL

```bash
# Get the external URL
kubectl get svc ingress-nginx-controller -n ingress-nginx

# Or use the helper script
./scripts/get-nginx-url.sh
```

### 2. Access Endpoints

Once you have the load balancer hostname:

```
🌐 Main App: http://<load-balancer-hostname>
❤️  Health Check: http://<load-balancer-hostname>/health
👥 API Users: http://<load-balancer-hostname>/api/users
📊 Metrics: http://<load-balancer-hostname>/metrics
```

### 3. Alternative Access (Port Forward)

```bash
# Always works for testing
kubectl port-forward -n flask-app svc/flask-app-service 8080:80

# Then access locally
curl http://localhost:8080/health
```

## CI/CD Pipelines

### Terraform Pipeline (`terraform.yml`)
- **PR**: Runs `terraform fmt`, `validate`, and `plan`
- **Main**: Runs `terraform apply` on merge

### Application Pipeline (`deploy-nginx.yml`)
- **PR**: Builds and tests Docker image
- **Main**: Builds, pushes to ECR, and deploys to EKS with ingress-nginx

## Monitoring

- **CloudWatch**: Cluster and application logs
- **Prometheus**: Metrics collection (optional)
- **Grafana**: Visualization dashboard (optional)

```bash
# Deploy monitoring (optional)
kubectl apply -f monitoring/
```

## Key Features

### ingress-nginx Benefits
- ✅ **Simple Setup**: No complex IAM/OIDC configuration
- ✅ **Single Load Balancer**: Cost-effective AWS NLB
- ✅ **Portable**: Works on any Kubernetes cluster
- ✅ **Feature Rich**: SSL, rate limiting, metrics built-in
- ✅ **Reliable**: Battle-tested in production environments

### Security Features
- Private subnets for worker nodes
- IAM roles with least privilege
- Security groups with minimal required access
- ECR image scanning enabled
- EKS cluster encryption at rest

## Troubleshooting

### Common Issues

1. **Load Balancer Not Ready**
   ```bash
   kubectl get svc -n ingress-nginx
   # Wait for EXTERNAL-IP to show hostname
   ```

2. **Application Not Responding**
   ```bash
   kubectl get pods -n flask-app
   kubectl logs -f deployment/flask-app -n flask-app
   ```

3. **kubectl Not Configured**
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name flask-eks-cluster
   ```

### Useful Commands

```bash
# Check all resources
kubectl get all -n flask-app

# Check ingress status
kubectl get ingress -n flask-app

# Check load balancer
kubectl get svc -n ingress-nginx

# View application logs
kubectl logs -f deployment/flask-app -n flask-app

# Port forward for testing
kubectl port-forward -n flask-app svc/flask-app-service 8080:80
```

## Cleanup

```bash
# Automated cleanup
./scripts/cleanup.sh

# Manual cleanup
kubectl delete namespace flask-app monitoring
cd terraform && terraform destroy
```

## Cost Optimization

- Uses single NLB instead of multiple ALBs
- Efficient resource allocation with HPA
- Spot instances can be enabled for cost savings
- Resource limits prevent over-provisioning

This setup provides a production-ready, cost-effective solution for deploying Flask microservices on EKS with reliable external access through ingress-nginx.