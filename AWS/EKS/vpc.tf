provider "aws" {
  region = "eu-west-2"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {}

################VPC######################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "EKS_VPC"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }

}

################Internet Gateway######################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

    tags = {
    Name = "EKS_Internet_GW"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

################Subnets######################################################

locals {
  availability_zones = data.aws_availability_zones.available.names
}

resource "aws_subnet" "eks_private" {
  count       = length(local.availability_zones)
  vpc_id      = aws_vpc.main.id
  cidr_block  = "10.0.${count.index + 1}.0/24"
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "EKS_Private_Subnet_${local.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/arsit-eks-cluster" = "owned"
  }
}

resource "aws_subnet" "private" {
  count       = length(local.availability_zones)
  vpc_id      = aws_vpc.main.id
  cidr_block  = "10.0.${count.index * 16 + 32}.0/24"
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "FargateProfiles_Private_Subnet_${local.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/arsit-eks-cluster" = "owned"
  }
}

resource "aws_subnet" "public" {
  count       = length(local.availability_zones)
  vpc_id      = aws_vpc.main.id
  cidr_block  = "10.0.${count.index + 5}.0/24"
  availability_zone = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "EKS_Public_Subnet_${local.availability_zones[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/arsit-eks-cluster" = "owned"
  }
}


################Nat IP######################################################
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "EKS_NAT_EIP"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

################Nat Gateway######################################################
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.private[0].id

  tags = {
    Name = "EKS_NAT_Gateway"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

################Route Table######################################################
resource "aws_route_table" "eks_private" {
  #count = length(local.availability_zones)
  vpc_id = aws_vpc.main.id

  

  tags = {
    Name = "EKS_Private_Route_Table"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

resource "aws_route_table" "private" {
  count = length(local.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat.*.id, 0)
  }

  tags = {
    Name = "FargateProfiles_Private_Route_Table_${local.availability_zones[count.index]}"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "EKS_Public_Route_Table"
    "kubernetes.io/cluster-name" = "arsit-eks-cluster"
    "kubernetes.io/cluster/cluster-oidc-enabled" = "false"
  }
}

resource "aws_route_table_association" "eks_private" {
  count          = length(aws_subnet.eks_private)
  subnet_id      = aws_subnet.eks_private[count.index].id
  route_table_id = aws_route_table.eks_private.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
