aws_region = "eu-central-1"

cluster_name    = "payment-api-eks"
cluster_version = "1.31"

vpc_cidr              = "10.0.0.0/16"
public_subnet_a_cidr  = "10.0.1.0/24"
public_subnet_b_cidr  = "10.0.2.0/24"
private_subnet_a_cidr = "10.0.11.0/24"
private_subnet_b_cidr = "10.0.12.0/24"

node_instance_type = "t3.medium"
node_desired_size  = 2
node_min_size      = 1
node_max_size      = 3

common_tags = {
  Project     = "eks-platform"
  Environment = "dev"
  ManagedBy   = "Terraform"
}

admin_user_arn = "arn:aws:iam::757906495185:user/adrian"

github_repository =  "adrian-cloud-devops/cloud-native-payment-api-eks"