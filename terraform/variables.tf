variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "notification_email" {
  description = "Email address for error notifications"
  type        = string
}

variable "monitored_lambda_name" {
  description = "Name of the Lambda function to monitor for errors"
  type        = string
  default     = "test-error-generator"
}

variable "exclusion_patterns" {
  description = "Comma-separated list of patterns to exclude from notifications"
  type        = string
  default     = "Rate Exceeded,request rate is too high"
}

variable "log_filter_pattern" {
  description = "CloudWatch Logs filter pattern"
  type        = string
  default     = "?ERROR ?CRITICAL"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "lambda-error-filter"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}