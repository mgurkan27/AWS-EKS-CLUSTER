provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  #version                = "~> 1.11"
}

data "aws_availability_zones" "available" {
}

locals {
  cluster_name = "my-cluster"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.47.0"

  name                 = "default"
  cidr                 = "172.31.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["subnet-018a35b712fae9164", "subnet-099fbca2a6444a553", "subnet-098bb7f2c5ad889b7"]
  public_subnets       = ["subnet-00e1eee87b22f7de6", "subnet-04c1849b52e2d8b87", "	subnet-037a607c049078310"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"

  cluster_name    = "my-cluster"
  cluster_version = "1.17"
  subnets         = ["subnet-018a35b712fae9164", "subnet-099fbca2a6444a553", "subnet-098bb7f2c5ad889b7"]

  vpc_id = "vpc-00064a63f9953eedc"

  node_groups = {
    first = {
      desired_capacity = 1
      max_capacity     = 4
      min_capacity     = 1

      instance_type = "t2.micro"
    }
  }

  write_kubeconfig   = true
  config_output_path = "./"
}
