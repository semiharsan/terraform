variable "aws_region" {
  description = "The AWS region where the ECR repository will be created."
  default     = "eu-west-2"
}

variable "ecr_repo_name" {
  description = "The name of the ECR repository to be created."
  default     = "arsit-ecr-repo"
}
