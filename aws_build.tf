terraform {
  required_providers {
      aws = {
          source = "hashicorp/aws"
          version = "~> 5.0"
      }
  }
}

provider "aws" {
  region = "us-west-2"
}

# resource "aws_dynamodb_table" "player_table" {
#   name = "terraform_players"
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key = "name"

#   attribute {
#       name = "name"
#       type = "S"
#   }
# }

data "aws_iam_policy_document" "assume_role" {
  statement {
      effect = "Allow"

      principals {
        type = "Service"
        identifiers = ["lambda.amazonaws.com"]
      }

      actions = ["sts:AssumeRole"]
  }
}

resource "aws_cloudwatch_log_group" "lambda-visitorcounter" {
  name = "/aws/lambda/${aws_lambda_function.delete_function.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamoroles" {
  role = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/delete/bootstrap"
  output_path = "${path.module}/delete/delete-lambda-handler.zip"
}

resource "aws_lambda_function" "delete_function" {
  filename = "${path.module}/delete/delete-lambda-handler.zip"
  function_name = "terraform_delete_player_function"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "hello.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "provided.al2023"
}

resource "aws_apigatewayv2_api" "delete_endpoint" {
  name = "terraform_delete_player_endpoint"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "dev" {
  api_id = aws_apigatewayv2_api.delete_endpoint.id

  name = "dev"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "delete_endpoint_integration" {
  api_id = aws_apigatewayv2_api.delete_endpoint.id
  integration_type = "AWS_PROXY"

  connection_type = "INTERNET"
  content_handling_strategy = "CONVERT_TO_TEXT"
  description = "Delete player by their name"
  integration_method = "DELETE"
  integration_uri = aws_lambda_function.delete_function.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_route" "delete_endpoint_route" {
  api_id = aws_apigatewayv2_api.delete_endpoint.id

  route_key = "DELETE /player"
  target = "integrations/${aws_apigatewayv2_integration.delete_endpoint_integration.id}"
}

resource "aws_lambda_permission" "api_invoke_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.delete_function
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.delete_endpoint.execution_arn}/*/*/*"
}