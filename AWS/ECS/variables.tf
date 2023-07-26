variable "aws_region" {
  description = "AWS region where the ECS cluster will be created."
  type        = string
  default     = "eu-west-2"  # Replace with your desired AWS region
}

variable "cluster_name" {
  description = "Name for the ECS cluster."
  type        = string
  default     = "arsit-ecs-cluster"
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository where your containers are stored."
  type        = string
  default     = "arsit-ecr-repo"
}

variable "ecr_image_tag" {
  description = "Tag of the specific ECR image you want to use."
  type        = string
  default     = "pythonapp"  # Replace with the specific tag of your desired ECR image
}
