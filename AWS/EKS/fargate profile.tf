locals {
  iam_role_name          = coalesce(var.iam_role_name, "fargate-profile")
  cni_policy             = var.cluster_ip_family == "ipv6" ? "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/AmazonEKS_CNI_IPv6_Policy" : "${local.iam_role_policy_prefix}/AmazonEKS_CNI_Policy"
}

################IAM Roles######################################################
data "aws_iam_policy_document" "assume_role_policy" {
  count = var.create && var.create_iam_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fargate" {
  count = var.create && var.create_iam_role ? 1 : 0

  name        = var.iam_role_use_name_prefix ? null : local.iam_role_name
  name_prefix = var.iam_role_use_name_prefix ? "${local.iam_role_name}-" : null
  path        = var.iam_role_path
  description = var.iam_role_description

  assume_role_policy    = data.aws_iam_policy_document.assume_role_policy[0].json
  permissions_boundary  = var.iam_role_permissions_boundary
  force_detach_policies = true

  tags = merge(var.tags, var.iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "fargate" {
  for_each = { for k, v in toset(compact([
    "${local.iam_role_policy_prefix}/AmazonEKSFargatePodExecutionRolePolicy",
    var.iam_role_attach_cni_policy ? local.cni_policy : "",
  ])) : k => v if var.create && var.create_iam_role }

  policy_arn = each.value
  role       = aws_iam_role.fargate[0].name
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = { for k, v in var.iam_role_additional_policies : k => v if var.create && var.create_iam_role }

  policy_arn = each.value
  role       = aws_iam_role.fargate[0].name
}

################Fargate Profile######################################################
resource "aws_eks_fargate_profile" "fargate_profile" {
  fargate_profile_name = "arsit-fargate"
  cluster_name         = aws_eks_cluster.eks_cluster.name
  pod_execution_role_arn = var.create_iam_role ? aws_iam_role.fargate[0].arn : var.iam_role_arn

  subnet_ids              = aws_subnet.private[*].id

  selector {
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }
  selector {
    namespace = "default"
  }
  
  tags = {
    Name = "Arsit_Fargate_Profile"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

output "fargate_pod_execution_role_arn" {
  value = aws_eks_fargate_profile.fargate_profile.pod_execution_role_arn
}