variable "region" {
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = null
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = null
}

variable "fargate_profile_name" {
  description = "Name of the Fargate Profile in EKS cluster"
  type        = string
  default     = null
}
