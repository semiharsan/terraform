provider "aws" {
  region = var.aws_region
}

resource "aws_iam_user" "jenkins" {
  name = var.iam_user_name
}

resource "aws_iam_user_policy_attachment" "jenkins_user_policy_attachment" {
  user       = aws_iam_user.jenkins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
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
