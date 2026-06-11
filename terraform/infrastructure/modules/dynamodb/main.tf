resource "aws_dynamodb_table" "payments" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "payment_id"

  attribute {
    name = "payment_id"
    type = "S"
  }

  tags = {
    Name = var.table_name
  }
}