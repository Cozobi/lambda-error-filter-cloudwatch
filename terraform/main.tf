terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# ============================================
# SNS Topic and Subscription
# ============================================

resource "aws_sns_topic" "error_notifications" {
  name = "lambda-error-notifications"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.error_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ============================================
# IAM Role for Error Processor Lambda
# ============================================

resource "aws_iam_role" "error_processor" {
  name = "error-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "error_processor" {
  name = "error-processor-policy"
  role = aws_iam_role.error_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.error_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/error-processor:*"
      }
    ]
  })
}

# ============================================
# IAM Role for Test Error Generator Lambda
# ============================================

resource "aws_iam_role" "test_error_generator" {
  name = "test-error-generator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "test_error_generator_basic" {
  role       = aws_iam_role.test_error_generator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================
# Lambda Functions
# ============================================

# Package error processor Lambda
data "archive_file" "error_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../src/error_processor"
  output_path = "${path.module}/files/error_processor.zip"
}

# Package test error generator Lambda
data "archive_file" "test_error_generator" {
  type        = "zip"
  source_dir  = "${path.module}/../src/test_error_generator"
  output_path = "${path.module}/files/test_error_generator.zip"
}

# Error Processor Lambda
resource "aws_lambda_function" "error_processor" {
  filename         = data.archive_file.error_processor.output_path
  function_name    = "error-processor"
  role             = aws_iam_role.error_processor.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.error_processor.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      snsARN             = aws_sns_topic.error_notifications.arn
      EXCLUSION_PATTERNS = var.exclusion_patterns
    }
  }

  tags = var.tags
}

# Test Error Generator Lambda
resource "aws_lambda_function" "test_error_generator" {
  filename         = data.archive_file.test_error_generator.output_path
  function_name    = var.monitored_lambda_name
  role             = aws_iam_role.test_error_generator.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.test_error_generator.output_base64sha256
  runtime          = "python3.12"
  timeout          = 10
  memory_size      = 128

  tags = var.tags
}

# ============================================
# CloudWatch Log Groups
# ============================================

resource "aws_cloudwatch_log_group" "error_processor" {
  name              = "/aws/lambda/error-processor"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "test_error_generator" {
  name              = "/aws/lambda/${var.monitored_lambda_name}"
  retention_in_days = 14
  tags              = var.tags
}

# ============================================
# Lambda Permission for CloudWatch Logs
# ============================================

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.error_processor.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.test_error_generator.arn}:*"
}

# ============================================
# CloudWatch Logs Subscription Filter
# ============================================

resource "aws_cloudwatch_log_subscription_filter" "error_filter" {
  name            = "error-filter"
  log_group_name  = aws_cloudwatch_log_group.test_error_generator.name
  filter_pattern  = var.log_filter_pattern
  destination_arn = aws_lambda_function.error_processor.arn

  depends_on = [aws_lambda_permission.allow_cloudwatch]
}