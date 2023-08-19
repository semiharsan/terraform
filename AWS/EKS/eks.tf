###############IAM Roles######################################################
resource "aws_iam_role" "eks_cluster" {
  name = "arsit-eks-cluster-role"

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
    Name = "Arsit_EKS_Cluster_Role"
  }
}

resource "aws_iam_policy_attachment" "eks_cluster_policy" {
  name       = "eks-cluster-policy-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_policy_attachment" "vpc_resource_controller_policy" {
  name       = "vpc-resource-controller-policy-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_elb" {
  name       = "eks-cluster-ec2-elb-policy-attachment"
  roles      = [aws_iam_role.eks_cluster.name]
  policy_arn = "arn:aws:iam::527410021310:policy/eks_cluster_policy_elb"
}

################Amazon EKS Cluster######################################################
resource "aws_eks_cluster" "eks_cluster" {
  name     = "arsit-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  #version = "1.27"

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = concat(aws_subnet.eks_private[*].id)
    public_access_cidrs     = ["0.0.0.0/0"]
  }
  
  depends_on = [aws_subnet.eks_private]
}

locals {
  create = var.create
  iam_role_policy_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  dns_suffix = coalesce(var.cluster_iam_role_dns_suffix, data.aws_partition.current.dns_suffix)
}

data "tls_certificate" "eks_cluster" {
  # Not available on outposts
  count = local.create ? 1 : 0

  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  # Not available on outposts
  count = local.create ? 1 : 0

  client_id_list  = distinct(compact(concat(["sts.${local.dns_suffix}"], var.openid_connect_audiences)))
  thumbprint_list = concat(data.tls_certificate.eks_cluster[count.index].certificates[*].sha1_fingerprint, var.custom_oidc_thumbprints)
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer

  tags = merge(
    { Name = "${aws_eks_cluster.eks_cluster.name}-eks-irsa" },
    var.tags
  )
}

################################################################################
# EKS Addons
################################################################################

resource "aws_eks_addon" "eks_cluster" {
  # Not supported on outposts
  for_each = { for k, v in var.cluster_addons : k => v if !try(v.before_compute, false) && local.create}

  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = try(each.value.name, each.key)

  addon_version            = coalesce(try(each.value.addon_version, null), data.aws_eks_addon_version.eks_cluster[each.key].version)
  configuration_values     = try(each.value.configuration_values, null)
  preserve                 = try(each.value.preserve, null)
  resolve_conflicts        = try(each.value.resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  timeouts {
    create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
    update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
    delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
  }

  depends_on = [aws_eks_fargate_profile.fargate_profile]

  tags = var.tags
}

resource "aws_eks_addon" "before_compute" {
  # Not supported on outposts
  for_each = { for k, v in var.cluster_addons : k => v if try(v.before_compute, false) && local.create}

  cluster_name = aws_eks_cluster.eks_cluster.name
  addon_name   = try(each.value.name, each.key)

  addon_version            = coalesce(try(each.value.addon_version, null), data.aws_eks_addon_version.eks_cluster[each.key].version)
  configuration_values     = try(each.value.configuration_values, null)
  preserve                 = try(each.value.preserve, null)
  resolve_conflicts        = try(each.value.resolve_conflicts, "OVERWRITE")
  service_account_role_arn = try(each.value.service_account_role_arn, null)

  timeouts {
    create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
    update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
    delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
  }

  tags = var.tags
}

data "aws_eks_addon_version" "eks_cluster" {
  for_each = { for k, v in var.cluster_addons : k => v if local.create}

  addon_name         = try(each.value.name, each.key)
  kubernetes_version = coalesce(var.cluster_version, aws_eks_cluster.eks_cluster.version)
  most_recent        = try(each.value.most_recent, null)
}

#################ADDONS######################################################
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

#resource "aws_eks_addon" "coredns" {
#  addon_name        = "coredns"
#  addon_version     = "v1.10.1-eksbuild.1"
#  cluster_name      = aws_eks_cluster.eks_cluster.name
#  resolve_conflicts_on_create = "OVERWRITE"
#  configuration_values        =jsonencode({computeType = "Fargate"})
#}

################################################################################
# EKS Identity Provider
# Note - eks_cluster is different from IRSA
################################################################################

resource "aws_eks_identity_provider_config" "eks_cluster" {
  for_each = { for k, v in var.cluster_identity_providers : k => v if local.create}

  cluster_name = aws_eks_cluster.eks_cluster.name

  oidc {
    client_id                     = each.value.client_id
    groups_claim                  = lookup(each.value, "groups_claim", null)
    groups_prefix                 = lookup(each.value, "groups_prefix", null)
    identity_provider_config_name = try(each.value.identity_provider_config_name, each.key)
    issuer_url                    = try(each.value.issuer_url, aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer)
    required_claims               = lookup(each.value, "required_claims", null)
    username_claim                = lookup(each.value, "username_claim", null)
    username_prefix               = lookup(each.value, "username_prefix", null)
  }

  tags = var.tags
}

################################################################################
# aws-auth configmap
################################################################################


locals {
    fargate_profile_pod_execution_role_arns = distinct(
    compact(
      concat(
        [
          aws_eks_fargate_profile.fargate_profile.pod_execution_role_arn
        ],
        var.aws_auth_fargate_profile_pod_execution_role_arns,
      )
    )
  )
   
   aws_auth_configmap_data = {
    mapRoles = yamlencode(concat(
      # Fargate profile
      [for role_arn in local.fargate_profile_pod_execution_role_arns : {
        rolearn  = role_arn
        username = "system:node:{{SessionName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes",
          "system:node-proxier",
        ]
        }
      ],
      var.aws_auth_roles
    ))
    mapUsers    = yamlencode(var.aws_auth_users)
    mapAccounts = yamlencode(var.aws_auth_accounts)
  }
}

resource "kubernetes_config_map" "aws_auth" {
  count = var.create && var.create_aws_auth_configmap ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  lifecycle {
    # We are ignoring the data here since we will manage it with the resource below
    # eks_cluster is only intended to be used in scenarios where the configmap does not exist
    ignore_changes = [data, metadata[0].labels, metadata[0].annotations]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.create && var.manage_aws_auth_configmap ? 1 : 0

  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.aws_auth_configmap_data

  depends_on = [
    # Required for instances where the configmap does not exist yet to avoid race condition
    kubernetes_config_map.aws_auth,
  ]
}