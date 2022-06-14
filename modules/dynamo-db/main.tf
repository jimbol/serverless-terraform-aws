# Here is a great guide - https://dynobase.dev/dynamodb-terraform/
# done forget to add lambda role if you havent already

resource "aws_dynamodb_table" "blog_table" {
  name           = "Blog"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "postId"

  attribute {
    name = "postId"
    type = "S"
  }

  tags = {
    Name        = "blog-table-${var.env}"
    Environment = var.env
  }
}
