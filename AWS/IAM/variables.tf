variable "cli_usr_access_key" {
  type    = string
  default = "write here your aws administrator user access key"
}
variable "cli_usr_secret_key" {
  type    = string
  default = "write here your aws administrator user secret key"
}

variable "aws_region" {
  description = "The AWS region where the resources will be provisioned."
  default     = "eu-west-2"
}

variable "iam_user_name" {
  description = "The name of the IAM user to be created."
  default     = "jenkins"
}
