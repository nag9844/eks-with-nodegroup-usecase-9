variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "node_group_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}