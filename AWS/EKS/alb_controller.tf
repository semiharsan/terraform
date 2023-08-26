provider "helm" {
  kubernetes {
    config_path = var.config_path  # Path to your kubeconfig file
  }
}

data "external" "eks_cluster_endpoint_check" {
  program = ["bash", "-c", <<EOF
    while ! curl --output /dev/null --silent --head --fail "${eks_cluster_endpoint}"; do
      echo "Cluster endpoint is not accessible. Retrying in 3 seconds..."
      sleep 3
    done
    echo "Cluster endpoint is accessible"
  EOF
  ]
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

  depends_on = [data.external.eks_cluster_endpoint_check]
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
