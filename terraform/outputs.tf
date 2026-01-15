output "sns_topic_arn" {
  description = "ARN of the SNS topic for error notifications"
  value       = aws_sns_topic.error_notifications.arn
}

output "error_processor_lambda_arn" {
  description = "ARN of the error processor Lambda function"
  value       = aws_lambda_function.error_processor.arn
}

output "test_error_generator_lambda_arn" {
  description = "ARN of the test error generator Lambda function"
  value       = aws_lambda_function.test_error_generator.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group being monitored"
  value       = aws_cloudwatch_log_group.test_error_generator.name
}

output "test_command" {
  description = "Command to test the solution"
  value       = "aws lambda invoke --function-name ${var.monitored_lambda_name} --region ${var.aws_region} response.json"
}