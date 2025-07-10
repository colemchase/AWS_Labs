provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "codepipeline:StartPipelineExecution",
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "webhook_trigger" {
  function_name = "github-webhook-trigger"
  role          = aws_iam_role.lambda_exec_role.arn
  runtime       = "python3.11"
  handler       = "lambda_function.lambda_handler"
  filename      = "lambda_function.zip"

  source_code_hash = filebase64sha256("lambda_function.zip")
}

resource "aws_apigatewayv2_api" "api" {
  name          = "webhook-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.webhook_trigger.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "route" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}
 

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_trigger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}






output "webhook_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
  description = "Paste this into the GitHub webhook Payload URL"
}
