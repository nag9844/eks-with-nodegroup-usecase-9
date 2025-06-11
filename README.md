# DevOps EKS Deployment - UseCase 9

A comprehensive solution for deploying Python Flask microservices to Amazon EKS using Infrastructure as Code (Terraform), CI/CD pipelines (GitHub Actions), and Kubernetes orchestration.

## Architecture Overview

This solution includes:
- **Infrastructure**: VPC, EKS cluster, ECR, IAM roles using Terraform
- **Containerization**: Docker images for Flask microservices
- **Orchestration**: Kubernetes deployments, services, and ingress
- **CI/CD**: GitHub Actions workflows for IaC and application deployment
- **Monitoring**: CloudWatch, Prometheus, and Grafana integration

## Directory Structure

```
├── .github/workflows/           # GitHub Actions workflows
├── modules/                     # Terraform modules
│   ├── vpc/                    # VPC module
│   ├── eks/                    # EKS module
│   ├── ecr/                    # ECR module
│   └── cloudwatch/             # CloudWatch module
├── app/                        # Flask microservices application
├── k8s/                        # Kubernetes manifests
├── monitoring/                 # Monitoring and logging configurations
├── docs/                       # Documentation and diagrams
├── main.tf                     # Main Terraform configuration
├── variables.tf                # Terraform variables
├── outputs.tf                  # Terraform outputs
└── terraform.tfvars.example    # Example variables file
```

## Backend Configuration

This project uses a centralized S3 backend for Terraform state management:

```hcl
terraform {
  backend "s3" {
    bucket       = "usecases-terraform-state-bucket"
    key          = "usecase9/statefile.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Docker
- GitHub repository with OIDC configured for AWS authentication

### Setup Instructions

1. **Configure GitHub OIDC**:
   - Ensure your GitHub repository has OIDC configured with AWS
   - The workflow uses role: `arn:aws:iam::199570228070:role/oidc-demo-role`

2. **Initialize Terraform**:
   ```bash
   # Copy example variables
   cp terraform.tfvars.example terraform.tfvars
   
   # Edit variables as needed
   vim terraform.tfvars
   
   # Initialize Terraform
   terraform init
   ```

3. **Deploy Infrastructure**:
   - Create a pull request to trigger Terraform plan
   - Merge to main branch to apply changes
   - Monitor deployment in GitHub Actions

4. **Deploy Application**:
   - Push application changes to trigger container build and deployment
   - Monitor deployment in Actions tab

5. **Access Application**:
   ```bash
   kubectl get ingress -n flask-app
   ```

## CI/CD Workflows

### Terraform CI/CD (`terraform-cicd.yml`)

**Triggers**:
- Pull requests to main branch
- Push to main branch
- Manual workflow dispatch

**Features**:
- Comprehensive linting with TFLint, tfsec, and Checkov
- Terraform format, validate, plan, and apply
- Automatic documentation generation with terraform-docs
- Pull request comments with plan output

### Application Deployment (`deploy-app.yml`)

**Triggers**:
- Push to main branch with changes to:
  - `app/**`
  - `k8s/**`
  - `Dockerfile`
  - Workflow file

**Features**:
- Docker image build and push to ECR
- Kubernetes deployment with rolling updates
- Deployment verification and status checks

## Security Features

- **OIDC Authentication**: Secure AWS access without long-lived credentials
- **Private Subnets**: EKS worker nodes in private subnets
- **Security Groups**: Minimal required access rules
- **IAM Roles**: Least privilege principles
- **Container Security**: Image scanning in ECR, non-root containers
- **Kubernetes RBAC**: Role-based access control enabled

## Monitoring

- **CloudWatch**: Cluster and application logs
- **Prometheus**: Metrics collection with custom application metrics
- **Grafana**: Visualization dashboards

Access Grafana dashboard:
```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

## Module Structure

### VPC Module
- Multi-AZ VPC with public and private subnets
- NAT gateways for outbound internet access
- Proper tagging for EKS integration

### EKS Module
- Managed EKS cluster with configurable version
- Auto-scaling node groups
- Essential add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)
- Security groups and IAM roles

### ECR Module
- Container registries with lifecycle policies
- Image scanning enabled
- Encryption at rest

### CloudWatch Module
- Log groups for cluster and application logs
- CloudWatch alarms for monitoring
- SNS integration for alerting

## Contributing

1. Create feature branch
2. Make changes
3. Submit pull request
4. Terraform plan will run automatically
5. Merge to main to deploy

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

For detailed setup instructions, see [Setup Guide](docs/setup.md).
For architecture details, see [Architecture Documentation](docs/architecture.md).