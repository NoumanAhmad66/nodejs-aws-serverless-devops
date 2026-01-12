terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.27.0"
    }
  }
}

provider "aws" {
  # use environment variables for credentials in GitHub Actions
  # and variables for region configuration
  region = var.aws_region
}
# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "hello-world-lambda-role-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM policy attachment
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role      = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Zip Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../app"
  output_path = "../lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "hello_lambda" {
  function_name = "hello-world-lambda-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "handler.handler"
  runtime       = "nodejs18.x"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "hello-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.hello_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

# Allow API Gateway to call Lambda
resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.hello_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}
######################################
# SNS Topic for Lambda Alerts
######################################
resource "aws_sns_topic" "lambda_alerts" {
  name = "lambda-error-alerts-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

######################################
# SNS Email Subscription
# 🔴 YAHAN APNA EMAIL DALO
######################################
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.lambda_alerts.arn
  protocol  = "email"
  endpoint  = "noumansdo737@gmail.com"
}

######################################
# CloudWatch Alarm for Lambda Errors
######################################
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "lambda-error-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0

  alarm_description = "Alarm when Lambda function errors exceed 0"

  alarm_actions = [
    aws_sns_topic.lambda_alerts.arn
  ]

  dimensions = {
    FunctionName = aws_lambda_function.hello_lambda.function_name
  }
}

