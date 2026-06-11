variable "name" {
  description = "Name prefix for IAM resources"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "ARN of DynamoDB table to grant access to"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of EKS OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of EKS OIDC provider (without https://)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the ServiceAccount"
  type        = string
}

variable "service_account_name" {
  description = "Kubernetes ServiceAccount name"
  type        = string
}