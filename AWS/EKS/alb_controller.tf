provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks_cluster.token
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

  depends_on = [null_resource.patch_coredns]
}

resource "null_resource" "update_eks_charts_repo" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    EOT
  }
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

  depends_on = [kubernetes_service_account.aws_load_balancer_controller,null_resource.update_eks_charts_repo]
}

#resource "kubernetes_service_account" "aws-pca-issuer" {
#  metadata {
#    name      = "aws-pca-issuer"
#    namespace = "aws-pca-issuer"
#
#    labels = {
#      "app.kubernetes.io/name"            = "aws-pca-issuer"
#      "eks.amazonaws.com/fargate-profile" = var.fargate_profile_name
#    }
#
#    annotations = {
#      "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AWSPCAIssuerIAMPolicyRole"
#    }
#  }
#
#  depends_on = [null_resource.patch_coredns]
#}

#resource "helm_release" "aws-pca-issuer" {
#  name = "aws-pca-issuer"
#
#  repository = "https://cert-manager.github.io/aws-privateca-issuer"
#  chart      = "aws-pca-issuer"
#  namespace  = "aws-pca-issuer"
#  version    = "0.1.2"
# 
#  set {
#    name  = "clusterName"
#    value = aws_eks_cluster.eks_cluster.id
#  }
#
#  set {
#    name  = "serviceAccount.create"
#    value = false
#  }
#  
#  set {
#    name  = "serviceAccount.name"
#    value = "aws-pca-issuer"
#  }
#
#  depends_on = [kubernetes_service_account.aws-pca-issuer,null_resource.update_eks_charts_repo]
#}

