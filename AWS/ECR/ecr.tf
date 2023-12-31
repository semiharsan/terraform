provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "arsit_ecr_repo" {
  name = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_id" {
  value = aws_ecr_repository.arsit_ecr_repo.id
}

output "ecr_registry_id" {
  value = aws_ecr_repository.arsit_ecr_repo.registry_id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.arsit_ecr_repo.repository_url
}
