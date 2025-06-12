terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"  # Change this to your bucket name
    key            = "eks-flask-app/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  
  required_version = ">= 1.0"
}