################IAM Roles for Fargate######################################################
resource "aws_iam_role" "fargate_profile" {
  name = "${var.cluster_name}-Fargate-Profile-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      "Effect": "Allow",
      "Condition": {
         "ArnLike": {
            "aws:SourceArn": "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:fargateprofile/${var.cluster_name}/*"
         }
      },
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
  })

  tags = {
    Name = "${var.cluster_name}-Fargate-Profile-Role"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "fargate_profile_pod_execution" {
  role       = aws_iam_role.fargate_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "fargate_profile_eks_cni_policy" {
  role       = aws_iam_role.fargate_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
################Fargate Profile######################################################
resource "aws_eks_fargate_profile" "fargate_profile" {
  fargate_profile_name = var.fargate_profile_name
  cluster_name         = aws_eks_cluster.eks_cluster.name
  pod_execution_role_arn = aws_iam_role.fargate_profile.arn

  subnet_ids              = aws_subnet.private[*].id

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }
  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
  selector {
    namespace = "default"
  }
  
  tags = {
    Name = var.fargate_profile_name
    "kubernetes.io/cluster-name" = var.cluster_name
  }
}

################Patch CoreDNS Deployment##############################################
#provider "kubernetes" {
#  config_path = var.config_path   # Path to your kubeconfig file
#}


