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

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
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