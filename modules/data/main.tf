variable "name" {
  type = string
}

variable "deletion_protection" {
  type = bool
}

resource "aws_dynamodb_table" "lab_requests" {
  name                        = "${var.name}-lab-requests"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "request_id"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "request_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

output "table_name" {
  value = aws_dynamodb_table.lab_requests.name
}

output "table_arn" {
  value = aws_dynamodb_table.lab_requests.arn
}
