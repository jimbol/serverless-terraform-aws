# Create Dynamo db to store results
resource "aws_dynamodb_table" "decoded_messages" {
  name           = "decoded_messages"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "decoded_id"
  range_key       = "decoded"

  attribute {
    name = "decoded_id"
    type = "S"
  }
  attribute {
    name = "decoded"
    type = "S"
  }

  tags = {
    Name        = "decoded-messages-table-${var.env}"
    Environment = var.env
  }
}

# Create sqs queue that takes encoded strings as messages
resource "aws_sqs_queue" "terraform_queue" {
  name                        = "terraform-example-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

data "archive_file" "lambda_definition" {

  type = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/build.zip"
}

resource "random_pet" "bucket" {}

resource "aws_s3_bucket" "lambda_zip_files" {
  bucket = "lambda-step-fn-zip-files-${random_pet.bucket.id}"
}

resource "aws_s3_object" "lambda_zip" {

  bucket = aws_s3_bucket.lambda_zip_files.id

  key    = "decode-message.zip"
  source = data.archive_file.lambda_definition.output_path

  etag = filemd5(data.archive_file.lambda_definition.output_path)
}


# lambda
resource "aws_iam_role" "step_fn_role" {
  name = "step_fn_role"

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
resource "aws_lambda_function" "decode_messages" {
  function_name = "decode-message"

  s3_bucket = aws_s3_bucket.lambda_zip_files.id
  s3_key    = aws_s3_object.lambda_zip.key

  runtime = "nodejs12.x"
  handler = "decode-message.handler"

  source_code_hash = data.archive_file.lambda_definition.output_base64sha256
  role = aws_iam_role.step_fn_role.arn
}


# Create step function
  # Trigger with encoded message: { "encoded": "aGVsbG8gd29ybGQ=" }
  # Pass to lambda for decoding
  # Write to Dynamodb
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "decode_and_save"
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
{
  "Comment": "Takes SQS event",
  "StartAt": "DecodeMessage",
  "States": {
    "DecodeMessage": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.decode_messages.arn}",
      "Next": "StoreDecoded"
    },
    "StoreDecoded": {
      "Type": "Task",
      "Resource": "arn:aws:states:::dynamodb:putItem",
      "Parameters": {
        "TableName": "decoded_messages",
        "Item": {
          "decoded_id": {
            "S.$": "$.decoded_id"
          },
          "decoded": {
            "S.$": "$.decoded"
          }
        }
      },
      "ResultPath": "$.dynamodbPut",
      "End": true
    }
  }
}
EOF
}

# create role for step fn
resource "aws_iam_role" "iam_for_sfn" {
  name = "sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "states.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
   name = "lambda_policy"
   role = aws_iam_role.iam_for_sfn.id
   policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : ["lambda:*"],
          "Resource" : aws_lambda_function.decode_messages.arn
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:PutItem"
          ],
          "Resource" : aws_dynamodb_table.decoded_messages.arn
        }
      ]
   })
}

# resource "aws_iam_role_policy" "dynamodb_policy" {
#    name = "dynamodb_policy"
#    role = aws_iam_role.iam_for_sfn.id
#    policy = jsonencode({
#       "Version" : "2012-10-17",
#       "Statement" : [

#       ]
#    })
# }

