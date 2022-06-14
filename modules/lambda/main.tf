#  Roll and policies
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb-lambda-policy" {
   name = "dynamodb_lambda_policy"
   role = aws_iam_role.lambda_exec.id
   policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
           "Effect" : "Allow",
           "Action" : ["dynamodb:*"],
           "Resource" : var.dynamo_table_arn
        }
      ]
   })
}
resource "aws_iam_role_policy" "rds-lambda-policy" {
   name = "rds_lambda_policy"
   role = aws_iam_role.lambda_exec.id
   policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
           "Effect" : "Allow",
           "Action" : ["rds-data:*"],
           "Resource" : var.aurora_arn
        }
      ]
   })
}
resource "aws_iam_role_policy" "secrets-lambda-policy" {
   name = "secrets_lambda_policy"
   role = aws_iam_role.lambda_exec.id
   policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
           "Effect" : "Allow",
           "Action" : ["secretsmanager:GetSecretValue"],
           "Resource" : "*"
        }
      ]
   })
}

# zip
data "archive_file" "lambda_definitions" {
  for_each = toset(var.lambdas)

  type = "zip"
  source_dir  = "${path.module}/src/${each.key}"
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "random_pet" "bucket" {}

resource "aws_s3_bucket" "lambda_zip_files" {
  bucket = "lambda-foobar-zip-files-${random_pet.bucket.id}"
}

resource "aws_s3_object" "lambda_zip" {
  for_each = toset(var.lambdas)

  bucket = aws_s3_bucket.lambda_zip_files.id

  key    = "${each.key}.zip"
  source = data.archive_file.lambda_definitions[each.key].output_path

  etag = filemd5(data.archive_file.lambda_definitions[each.key].output_path)
}

# lambda
resource "aws_lambda_function" "foobar_lambdas" {
  for_each = toset(var.lambdas)

  function_name = each.key

  s3_bucket = aws_s3_bucket.lambda_zip_files.id
  s3_key    = aws_s3_object.lambda_zip[each.key].key

  runtime = "nodejs12.x"
  handler = "${each.key}.handler"

  source_code_hash = data.archive_file.lambda_definitions[each.key].output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

