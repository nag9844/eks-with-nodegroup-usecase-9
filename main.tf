data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment            = var.environment
  project               = var.project
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  
  tags = var.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  environment         = var.environment
  project            = var.project
  cluster_name       = "${var.project}-cluster-${var.environment}"
  cluster_version    = var.cluster_version
  
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
  node_disk_size      = var.node_disk_size
  
  tags = var.common_tags
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  environment       = var.environment
  project          = var.project
  repository_name  = var.ecr_repository_name
  
  tags = var.common_tags
}

# CloudWatch Module
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  environment         = var.environment
  project            = var.project
  cluster_name       = module.eks.cluster_name
  log_retention_days = var.log_retention_days
  
  tags = var.common_tags
}