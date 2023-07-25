provider "aws" {
  region = var.aws_region
  access_key = var.cli_usr_access_key
  secret_key = var.cli_usr_secret_key
}


resource "aws_iam_user" "jenkins" {
  name = var.iam_user_name
}

resource "aws_iam_policy" "jenkins_user_policy" {
  name        = "JenkinsUserPolicy"
  description = "IAM policy for Jenkins user to manage ECR, ECS, and EKS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:CreateRepository",
          "ecr:DescribeRepositories",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepository",
          "ecr:DeleteRepositoryPolicy"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:DescribeTaskDefinition",
          "ecs:CreateCluster",
          "ecs:DeleteCluster",
          "ecs:DescribeClusters",
          "ecs:ListClusters",
          "ecs:ListContainerInstances",
          "ecs:DescribeContainerInstances",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:CreateService",
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:RunTask"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "eks:CreateCluster",
          "eks:DeleteCluster",
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeFargateProfile",
          "eks:CreateFargateProfile",
          "eks:DeleteFargateProfile",
          "eks:UpdateClusterVersion",
          "eks:UpdateNodegroupVersion",
          "eks:DescribeAddon",
          "eks:DescribeAddonVersions",
          "eks:ListAddons",
          "eks:CreateAddon",
          "eks:DeleteAddon",
          "eks:TagResource",
          "eks:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_user_policy_attachment" {
  user       = aws_iam_user.jenkins_user.name
  policy_arn = aws_iam_policy.jenkins_user_policy.arn
}


resource "aws_iam_access_key" "iam_user_access_key" {
  user = aws_iam_user.jenkins.name
}

resource "local_file" "access_key_file" {
  filename = "access_key.txt"
  content  = aws_iam_access_key.iam_user_access_key.id
}

resource "local_file" "secret_key_file" {
  filename = "secret_key.txt"
  content  = aws_iam_access_key.iam_user_access_key.secret
}
