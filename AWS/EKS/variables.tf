variable "region" {
  default     =var.REGION
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = var.VPC_CIDR
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = var.CLUSTER_NAME
}

variable "fargate_profile_name" {
  description = "Name of the Fargate Profile in EKS cluster"
  type        = string
  default     = var.FARGATE_PROFILE_NAME
}
