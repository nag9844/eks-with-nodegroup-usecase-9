# Setup Guide

This guide will help you set up the complete DevOps environment for deploying Flask microservices to AWS EKS.

## Prerequisites

Before starting, ensure you have:

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- kubectl installed
- Docker installed
- GitHub repository with the following secrets configured:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION`

## AWS Permissions Required

Your AWS user/role needs the following permissions:
- VPC management (create VPC, subnets, security groups)
- EKS cluster management
- ECR repository management
- IAM role management
- S3 bucket management (for Terraform state)
- DynamoDB management (for Terraform state locking)
- CloudWatch management

## Step-by-Step Setup

### 1. Initialize Terraform Backend

First, create the S3 backend for Terraform state management:

```bash
# Navigate to terraform directory
cd terraform/environments/dev

# Uncomment the terraform_backend module in main.tf
# Run terraform init and apply to create S3 bucket and DynamoDB table
terraform init
terraform apply -target=module.terraform_backend

# Note the S3 bucket name and update the backend configuration
# Comment out the terraform_backend module after creation
```

### 2. Deploy Infrastructure

```bash
# Initialize with remote backend
terraform init

# Plan the deployment
terraform plan

# Apply the infrastructure
terraform apply
```

This will create:
- VPC with public and private subnets
- EKS cluster with managed node groups
- ECR repositories
- IAM roles and security groups
- CloudWatch log groups

### 3. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name eks-cluster-dev

# Verify connection
kubectl get nodes
```

### 4. Deploy Monitoring Stack

```bash
# Deploy monitoring namespace and components
kubectl apply -f monitoring/namespace.yaml
kubectl apply -f monitoring/
```

### 5. Configure GitHub Actions

Ensure your GitHub repository has the required secrets:

```bash
# In your GitHub repository settings, add secrets:
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=ap-south-1
```

### 6. Deploy Application

Push your code changes to trigger the GitHub Actions workflow:

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

The workflow will:
1. Build the Docker image
2. Push to ECR
3. Deploy to EKS
4. Update Kubernetes manifests

## Accessing Your Application

### Application Endpoints

```bash
# Get the LoadBalancer URL
kubectl get service flask-app-service -n flask-app

# Or use the ingress
kubectl get ingress flask-app-ingress -n flask-app
```

### Monitoring Dashboards

#### Grafana
```bash
# Port forward to access Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# Access at http://localhost:3000
# Default credentials: admin/admin123
```

#### Prometheus
```bash
# Port forward to access Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Access at http://localhost:9090
```

## Cleanup

To destroy all resources:

```bash
# Delete Kubernetes resources
kubectl delete namespace flask-app
kubectl delete namespace monitoring

# Destroy Terraform infrastructure
terraform destroy
```

## Troubleshooting

### Common Issues

1. **EKS Cluster Access Issues**
   ```bash
   # Verify IAM permissions
   aws iam get-user
   
   # Update kubeconfig
   aws eks update-kubeconfig --region ap-south-1 --name eks-cluster-dev
   ```

2. **Application Not Starting**
   ```bash
   # Check pod logs
   kubectl logs -n flask-app deployment/flask-app
   
   # Check pod status
   kubectl get pods -n flask-app
   ```

3. **Terraform State Issues**
   ```bash
   # Refresh state
   terraform refresh
   
   # Import existing resources if needed
   terraform import aws_eks_cluster.main eks-cluster-dev
   ```

### Monitoring and Alerting

- CloudWatch logs are automatically configured for EKS cluster
- Prometheus scrapes metrics from application pods
- Grafana provides visualization dashboards
- SNS topic configured for alerts (optional email notification)

## Security Considerations

- EKS cluster uses private subnets for worker nodes
- Security groups follow least privilege principle
- Container images are scanned in ECR
- Kubernetes RBAC is enabled
- All resources use encryption at rest
- Non-root containers with security contexts

For additional help, check the [Architecture Documentation](architecture.md).