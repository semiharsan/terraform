provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

################VPC######################################################
resource "aws_vpc" "main" {
  cidr_block            = var.vpc_cidr
  enable_dns_hostnames  = true
  enable_dns_support    = true
  #instance_tenancy     = "default"

  tags = {
    Name                          = "${var.cluster_name}_Vpc"
    "kubernetes.io/cluster-name"  = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

}

################Internet Gateway######################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name                         = "${var.cluster_name}_Internet_Gateway"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }
}

################Subnets######################################################
locals {
  availability_zones = data.aws_availability_zones.available.names
}

resource "aws_subnet" "private" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index)
  availability_zone = local.availability_zones[count.index]

  tags = {
    Name = "${var.cluster_name}_Private_Subnet_${local.availability_zones[count.index]}"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_subnet" "public" {
  count             = length(local.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 4, count.index + 4)
  availability_zone = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}_Public_Subnet_${local.availability_zones[count.index]}"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

################Nat IP & Gateway###################################################
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}_EIP"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.cluster_name}_NAT_Gateway"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

################Route Table######################################################
resource "aws_route_table" "private" {
  count  = length(local.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.nat.*.id, 0)
  }

  tags = {
    Name = "${var.cluster_name}_Private_Route_Table_${local.availability_zones[count.index]}"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}_Public_Route_Table}"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
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

################Security Groups######################################################
resource "aws_security_group" "cluster_shared_node_security_group" {
  count        = 1
  name         = "${var.cluster_name}-ClusterSharedNodeSecurityGroup"
  description  = "Communication between all nodes in the cluster"
  vpc_id       = aws_vpc.main.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}/ClusterSharedNodeSecurityGroup"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }
}

resource "aws_security_group" "control_plane_security_group" {
  count        = 1
  name         = "${var.cluster_name}-ControlPlaneSecurityGroup"
  description  = "Communication between the control plane and worker nodegroups"
  vpc_id       = aws_vpc.main.id
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}/ControlPlaneSecurityGroup"
    "kubernetes.io/cluster-name" = var.cluster_name
    "k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }
}
