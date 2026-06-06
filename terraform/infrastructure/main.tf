data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr              = var.vpc_cidr
  public_subnet_a_cidr  = var.public_subnet_a_cidr
  public_subnet_b_cidr  = var.public_subnet_b_cidr
  private_subnet_a_cidr = var.private_subnet_a_cidr
  private_subnet_b_cidr = var.private_subnet_b_cidr
  az_a                  = data.aws_availability_zones.available.names[0]
  az_b                  = data.aws_availability_zones.available.names[1]
  cluster_name          = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "ecr" {
  source = "./modules/ecr"

  repository_name = "payment-api"
}

module "github_actions_iam" {
  source = "./modules/github-actions-iam"

  cluster_name      = var.cluster_name
  github_repository = var.github_repository
  aws_account_id    = data.aws_caller_identity.current.account_id
  ecr_repository_arn = module.ecr.repository_arn
}