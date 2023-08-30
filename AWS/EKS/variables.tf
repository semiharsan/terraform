variable "region" {
  default     = "eu-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "Arsit-Eks"
}

variable "fargate_profile_name" {
  description = "Name of the Fargate Profile in EKS cluster"
  type        = string
  default     = "Arsit-Eks-Fargate"
}

variable "iam_user_name" {
  description = "IAM user who needs to access EKS resources from aws console"
  type        = string
  default     = "jenkins"
}

#variable "config_path" {
#  description = "Path for your Kube config file"
#  type        = string
#  default     = "C:\\Users\\semih\\.kube\\config"
#}