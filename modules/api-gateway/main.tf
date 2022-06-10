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
}

resource "aws_lambda_permission" "api_gw" {
  for_each = var.lambdas

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}
