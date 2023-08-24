#provider "helm" {
#  kubernetes {
#    host                   = aws_eks_cluster.eks_cluster.endpoint
#    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
#    exec {
#      api_version = "client.authentication.k8s.io/v1beta1"
#      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.eks_cluster.id]
#      command     = "aws"
#    }
#  }
#}

provider "helm" {
  kubernetes {
    config_path = "C:\\Users\\semih\\.kube\\config"  # Path to your kubeconfig file
  }
}

resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/component"       = "controller"
      "app.kubernetes.io/name"            = "aws-load-balancer-controller"
      "eks.amazonaws.com/fargate-profile" = var.fargate_profile_name
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AmazonEKSLoadBalancerControllerRole"
    }
  }

  depends_on = [aws_eks_fargate_profile.fargate_profile]
}

resource "helm_release" "aws-load-balancer-controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.0"
 
  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks_cluster.id
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = aws_vpc.main.id
  }

  depends_on = [kubernetes_service_account.aws_load_balancer_controller]
}
