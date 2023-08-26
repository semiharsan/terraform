###############IAM Roles for EKS######################################################
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-EKSCluster-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-EKSCluster-Role"
  }
}

resource "aws_iam_policy_attachment" "eks_cluster_policy" {
  name       = "${var.cluster_name}-cluster-policy-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_policy_attachment" "vpc_resource_controller_policy" {
  name       = "${var.cluster_name}-vpc-resource-controller-policy-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

data "aws_iam_policy_document" "eks_cluster_policy_cloudwatch" {
  version = "2012-10-17"
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "eks_cluster_policy_cloudwatch" {
  name        = "${var.cluster_name}PolicyForCloudWatch"
  policy      = data.aws_iam_policy_document.eks_cluster_policy_cloudwatch.json
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_cloudwatch" {
  name       = "${var.cluster_name}-policy-cloudwatch-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = aws_iam_policy.eks_cluster_policy_cloudwatch.arn
}

data "aws_iam_policy_document" "eks_cluster_policy_elb" {
  version = "2012-10-17"

  statement {
    actions   = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeInternetGateways",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:ListTagsForResource",
      "ecr:DescribeImageScanFindings"
    ]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "eks_cluster_policy_elb" {
  name        = "${var.cluster_name}PolicyForELB"
  policy      = data.aws_iam_policy_document.eks_cluster_policy_elb.json
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_elb" {
  name       = "${var.cluster_name}-policy-elb-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = aws_iam_policy.eks_cluster_policy_elb.arn
}

################Amazon EKS Cluster######################################################
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  #version = "1.27"

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids              = concat(aws_subnet.public[*].id,aws_subnet.private[*].id)
    public_access_cidrs     = ["0.0.0.0/0"]
  }
  
  depends_on = [aws_subnet.public,aws_subnet.private]
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}
#################OIDC######################################################
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}
################AWS Load Balancer Controller##################################
resource "aws_iam_role" "aws_load_balancer_controller" {
    name = "AmazonEKSLoadBalancerControllerRole"
  
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
      {
        "Effect": "Allow",
        "Condition": {
           "StringEquals": {
            "${aws_iam_openid_connect_provider.eks.url}:aud": "sts.amazonaws.com",
            "${aws_iam_openid_connect_provider.eks.url}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
           }
        },
        "Principal": {
            "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${aws_iam_openid_connect_provider.eks.url}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity"
      }
    ]
    })
  
    tags = {
      Name = "AmazonEKSLoadBalancerControllerRole"
      "kubernetes.io/cluster-name" = var.cluster_name
      "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    }

    depends_on = [aws_iam_openid_connect_provider.eks]
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  policy = file("./albc-iam-policy.json")
  name   = "AWSLoadBalancerControllerIAMPolicy"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

output "aws_load_balancer_controller_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

#################Addons######################################################

resource "aws_eks_addon" "vpc-cni" {
  addon_name        = "vpc-cni"
  addon_version     = "v1.13.4-eksbuild.1"
  cluster_name      = aws_eks_cluster.eks_cluster.name
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "kube-proxy" {
  addon_name        = "kube-proxy"
  addon_version     = "v1.27.1-eksbuild.1"
  cluster_name      = aws_eks_cluster.eks_cluster.name
  resolve_conflicts_on_create = "OVERWRITE"
}
