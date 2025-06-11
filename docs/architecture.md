# Architecture Documentation

## Overview

This document describes the architecture of the Flask microservice deployment on AWS EKS using Infrastructure as Code (Terraform) and CI/CD pipelines (GitHub Actions).

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                           AWS Cloud                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                        VPC                                  ││
│  │  ┌──────────────────┐    ┌──────────────────┐               ││
│  │  │  Public Subnet   │    │  Public Subnet   │               ││
│  │  │   (AZ-1)         │    │   (AZ-2)         │               ││
│  │  │                  │    │                  │               ││
│  │  │  ┌─────────────┐ │    │ ┌─────────────┐  │               ││
│  │  │  │ NAT Gateway │ │    │ │ NAT Gateway │  │               ││
│  │  │  └─────────────┘ │    │ └─────────────┘  │               ││
│  │  └──────────────────┘    └──────────────────┘               ││
│  │  ┌──────────────────┐    ┌──────────────────┐               ││
│  │  │ Private Subnet   │    │ Private Subnet   │               ││
│  │  │   (AZ-1)         │    │   (AZ-2)         │               ││
│  │  │                  │    │                  │               ││
│  │  │ ┌─────────────┐  │    │ ┌─────────────┐  │               ││
│  │  │ │ EKS Nodes   │  │    │ │ EKS Nodes   │  │               ││
│  │  │ └─────────────┘  │    │ └─────────────┘  │               ││
│  │  └──────────────────┘    └──────────────────┘               ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │       ECR       │  │   CloudWatch    │  │      EKS        │  │
│  │   Container     │  │   Monitoring    │  │   Control       │  │
│  │   Registry      │  │   & Logging     │  │    Plane        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. Network Layer (VPC)

- **VPC**: Isolated network environment with CIDR 10.0.0.0/16
- **Public Subnets**: For load balancers and NAT gateways (2 AZs)
- **Private Subnets**: For EKS worker nodes (2 AZs)
- **Internet Gateway**: Internet access for public subnets
- **NAT Gateways**: Outbound internet access for private subnets

### 2. Container Orchestration (EKS)

- **Control Plane**: Managed by AWS in multiple AZs
- **Node Groups**: Auto-scaling groups of EC2 instances
- **Networking**: AWS VPC CNI for pod networking
- **Security**: IAM roles for service accounts (IRSA)

### 3. Application Layer

```
┌─────────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                 flask-app namespace                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          ││
│  │  │    Pod      │  │    Pod      │  │    Pod      │          ││
│  │  │ Flask App   │  │ Flask App   │  │ Flask App   │          ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘          ││
│  │         │                 │                 │               ││
│  │  ┌─────────────────────────────────────────────────────┐    ││
│  │  │              Service (LoadBalancer)                 │    ││
│  │  └─────────────────────────────────────────────────────┘    ││
│  │  ┌─────────────────────────────────────────────────────┐    ││
│  │  │              Ingress Controller                     │    ││
│  │  └─────────────────────────────────────────────────────┘    ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                monitoring namespace                         ││
│  │  ┌─────────────┐              ┌─────────────┐               ││
│  │  │ Prometheus  │              │   Grafana   │               ││
│  │  │             │──────────────│             │               ││
│  │  └─────────────┘              └─────────────┘               ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### 4. CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Terraform Plan  │  │ Terraform Apply │  │ App Deployment  │  │
│  │   (on PR)       │  │  (on merge)     │  │  (on app push)  │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │         │
│           │                     │                     │         │
│           ▼                     ▼                     ▼         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   Validation    │  │  Infrastructure │  │ Container Build │  │
│  │   & Linting     │  │   Provisioning  │  │   & Deploy      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### 1. Network Security

- **Private Subnets**: EKS worker nodes in private subnets
- **Security Groups**: Least privilege access rules
- **NACLs**: Additional network-level security (default)

### 2. Identity and Access Management

- **EKS Service Role**: For cluster management
- **Node Group Role**: For EC2 instances
- **Pod Security**: Security contexts and non-root containers
- **RBAC**: Kubernetes role-based access control

### 3. Container Security

- **Image Scanning**: ECR vulnerability scanning
- **Non-root Containers**: Security contexts
- **Resource limits**: CPU and memory constraints
- **Read-only filesystems**: Where applicable

## Monitoring Architecture

### 1. Metrics Collection

- **Prometheus**: Scrapes metrics from pods and Kubernetes API
- **CloudWatch**: AWS native monitoring for EKS and infrastructure
- **Application Metrics**: Custom Flask application metrics

### 2. Logging

- **CloudWatch Logs**: EKS cluster and application logs
- **FluentBit**: Log forwarding (optional)
- **Structured Logging**: JSON formatted application logs

### 3. Visualization

- **Grafana**: Custom dashboards for application metrics
- **CloudWatch Dashboards**: AWS resource monitoring
- **Alerting**: Prometheus AlertManager integration

## Data Flow

### 1. Request Flow

```
Internet → ALB → EKS Service → Pod → Flask Application
```

### 2. Deployment Flow

```
GitHub Push → Actions → Docker Build → ECR Push → K8s Deploy
```

### 3. Monitoring Flow

```
Application → Prometheus → Grafana
      ↓
  CloudWatch
```

## Scalability Design

### 1. Horizontal Pod Autoscaler (HPA)

- **CPU-based scaling**: Scale based on CPU utilization
- **Memory-based scaling**: Scale based on memory usage
- **Custom metrics**: Scale based on application metrics

### 2. Cluster Autoscaler

- **Node scaling**: Automatically add/remove nodes
- **Multi-AZ**: Distribute across availability zones
- **Spot instances**: Cost optimization (optional)

### 3. Application Scaling

- **Stateless design**: No local state in containers
- **Load balancing**: Even distribution of requests
- **Health checks**: Proper liveness and readiness probes

## Disaster Recovery

### 1. Multi-AZ Deployment

- **EKS Control Plane**: Automatically distributed across AZs
- **Worker Nodes**: Deployed across multiple AZs
- **Data Persistence**: EBS volumes with snapshot backups

### 2. Backup Strategy

- **Terraform State**: Stored in S3 with versioning
- **Application Data**: External database with automated backups
- **Configuration**: Git-based infrastructure as code

### 3. Recovery Procedures

- **Infrastructure**: Terraform apply for infrastructure recreation
- **Application**: GitHub Actions for application redeployment
- **Data**: Database restore from backups

## Cost Optimization

### 1. Resource Right-sizing

- **T3 instances**: Burstable performance for variable workloads
- **Spot instances**: Cost savings for non-critical workloads
- **Auto-scaling**: Scale down during low usage periods

### 2. Storage Optimization

- **EBS GP3**: Cost-effective storage with configurable performance
- **ECR Lifecycle**: Automatic cleanup of old container images
- **Log retention**: CloudWatch log retention policies

### 3. Monitoring and Alerting

- **Cost alerts**: CloudWatch billing alarms
- **Resource utilization**: Right-sizing recommendations
- **Waste identification**: Unused resources cleanup

This architecture provides a robust, scalable, and secure foundation for deploying microservices on AWS EKS with comprehensive monitoring and CI/CD capabilities.