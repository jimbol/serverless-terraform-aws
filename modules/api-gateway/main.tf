resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "serverless_lambda_api_gateway_${var.env}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda_api.id

  name        = "api_stage_${var.env}"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_api_gateway_integration" {
  for_each = var.lambdas

  api_id = aws_apigatewayv2_api.lambda_api.id

  integration_uri    = each.value.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda" {
  for_each = var.lambdas

  api_id = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /${each.value.function_name}"
  target    = "integrations/${
    aws_apigatewayv2_integration.lambda_api_gateway_integration[
      each.value.function_name
    ].id
  }"

  # add along with auth
  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.auth.id
}

resource "aws_lambda_permission" "api_gw" {
  for_each = var.lambdas

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# Cognito
# guide - https://andrewtarry.com/posts/aws-http-gateway-with-cognito-and-terraform/
# (testing steps below)
resource "aws_apigatewayv2_authorizer" "auth" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.client.id]
    issuer   = "https://${aws_cognito_user_pool.pool.endpoint}"
  }
}

resource "aws_cognito_user_pool" "pool" {
  name = "app_user_pool"
}

resource "aws_cognito_user_pool_client" "client" {
  name = "app_external_api"
  user_pool_id = aws_cognito_user_pool.pool.id
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

/*
Guide for curling - https://sanderknape.com/2020/08/amazon-cognito-jwts-authenticate-amazon-http-api/

# TEST
curl --request GET 'https://ggyd7ud9yl.execute-api.us-east-2.amazonaws.com/api_stage_dev/foo'

# Create user in cognito console

# update password
aws --profile=default cognito-idp admin-set-user-password \
--region "us-east-2" \
--user-pool-id "${POOL_ID}" \
--username "jim" \
--password "P@ssword123" \
--permanent

# log in
## with aws cli
```
aws --profile=default cognito-idp initiate-auth \
    --region "us-east-2" \
    --client-id "65a8t8j1adisehlludvnh8403s" \
    --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters USERNAME="jim",PASSWORD="P@ssword123" \
    --query 'AuthenticationResult.AccessToken' \
    --output text
```

## ...or with curl
```
curl --location --request POST 'https://cognito-idp.us-east-2.amazonaws.com' \
--header 'X-Amz-Target: AWSCognitoIdentityProviderService.InitiateAuth' \
--header 'Content-Type: application/x-amz-json-1.1' \
--data-raw '{
   "AuthParameters" : {
      "USERNAME" : "jim",
      "PASSWORD" : "P@ssword123"
   },
   "AuthFlow" : "USER_PASSWORD_AUTH",
   "ClientId" : "65a8t8j1adisehlludvnh8403s"
}'
```

# then use the auth token in a request
curl -s -D - -H "Authorization: Bearer ${TOKEN}" 'https://ggyd7ud9yl.execute-api.us-east-2.amazonaws.com/api_stage_dev/foo'

*/
