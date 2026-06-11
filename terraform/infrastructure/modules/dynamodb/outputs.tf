output "table_name" {
  value = aws_dynamodb_table.payments.name
}

output "table_arn" {
  value = aws_dynamodb_table.payments.arn
}