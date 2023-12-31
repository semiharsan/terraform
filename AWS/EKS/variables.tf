variable "region" {
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "fargate_profile_name" {
  description = "Name of the Fargate Profile in EKS cluster"
  type        = string
}

variable "iam_user_name" {
  description = "IAM user who needs to access EKS resources from aws console"
  type        = string
}
