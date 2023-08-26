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
provider "kubernetes" {
  config_path = var.config_path   # Path to your kubeconfig file
}

resource "null_resource" "patch_coredns" {
  triggers = {
    eks_cluster_id = aws_eks_cluster.eks_cluster.id
  }

  provisioner "local-exec" {
    environment = {
      AWS_REGION = var.region  # This is your pipeline variable
      EKS_CLUSTER_NAME = var.cluster_name  # This is your pipeline variable
      EKS_CLUSTER_ENDPOINT = aws_eks_cluster.eks_cluster.endpoint  # This is eks resource output value
    }
    command = <<-EOT
      sudo -u jenkins aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME
      kubectl patch deployment coredns -n kube-system --type json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
      kubectl rollout restart -n kube-system deployment coredns
      kubectl -n kube-system wait deployment/coredns --for=condition=Available --timeout=60s
      kubectl -n kube-system wait pods -l k8s-app=kube-dns --for=condition=Ready --timeout=60s
      kubectl -n kube-system get all
      while ! curl --output /dev/null --silent --head --fail "$EKS_CLUSTER_ENDPOINT"; do
      echo "Cluster endpoint is not accessible. Retrying in 3 seconds..."
      sleep 3
      done
      echo "Cluster endpoint is accessible"
    EOT
  }

  depends_on = [aws_eks_fargate_profile.fargate_profile]
}
