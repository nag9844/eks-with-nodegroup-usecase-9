# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  cluster_name       = var.cluster_name
  environment        = var.environment
  project_name       = var.project_name
}

# ECR Module
module "ecr" {
  source = "./modules/ecr"
  
  repository_name = "${var.project_name}-app"
  environment     = var.environment
  project_name    = var.project_name
}

# EKS Module
module "eks" {
  source = "./modules/eks"
  
  cluster_name                 = var.cluster_name
  cluster_version             = var.cluster_version
  vpc_id                      = module.vpc.vpc_id
  private_subnet_ids          = module.vpc.private_subnet_ids
  public_subnet_ids           = module.vpc.public_subnet_ids
  node_group_instance_types   = var.node_group_instance_types
  node_group_desired_size     = var.node_group_desired_size
  node_group_max_size         = var.node_group_max_size
  node_group_min_size         = var.node_group_min_size
  environment                 = var.environment
  project_name                = var.project_name
}

# S3 bucket for Terraform state (if not exists)
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state-${random_id.bucket_suffix.hex}"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "random_id" "bucket_suffix" {
  byte_length = 4
}