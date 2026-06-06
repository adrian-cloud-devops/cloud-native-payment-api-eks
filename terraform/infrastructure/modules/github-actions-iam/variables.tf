variable "cluster_name"       { type = string }
variable "github_repository"  { type = string }
variable "aws_account_id"     { type = string }
variable "ecr_repository_arn" { type = string }

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}