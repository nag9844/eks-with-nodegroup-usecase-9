output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

# output "public_subnet_ids" {
#   description = "Public subnet IDs"
#   value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
# }

# output "private_subnet_ids" {
#   description = "Private subnet IDs"
#   value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
# }

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  # value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  value       = module.eks.cluster_security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  # value       = aws_ecr_repository.flask_microservice.repository_url
  value       = module.ecr.repository_url
}

output "kubeconfig_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  # value       = aws_eks_cluster.main.certificate_authority[0].data
  value = module.eks.kubeconfig_certificate_authority_data[0].data
  sensitive   = true
}

output "region" {
  description = "AWS region"
  value       = "ap-south-1"
}