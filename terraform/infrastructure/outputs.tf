output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority
  sensitive   = true
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions — GitHub Secrets"
  value       = module.github_actions_iam.role_arn
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "payment_api_role_arn" {
  description = "IAM Role ARN for payment-api pod — wklej do serviceaccount.yaml"
  value       = module.irsa.role_arn
}