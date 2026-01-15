# Lambda Error Filter with CloudWatch Logs

Filter CloudWatch Logs error notifications to exclude specific patterns (e.g., rate limit errors) before sending SNS email alerts.

## Problem Statement

When using CloudWatch Logs subscription filters for Lambda error monitoring, you may want to exclude certain error patterns to avoid notification spam.

**Challenge**: CloudWatch Logs subscription filter patterns **do not support negative matching or exclusions**.

**Solution**: Handle the exclusion logic within the error-processor Lambda function.

## Architecture

![Architecture Diagram](https://d2908q01vomqb2.cloudfront.net/972a67c48192728a34979d9a35164c1295401b71/2020/08/10/customlambdaerror_arch.png)


## Prerequisites

- AWS Account
- AWS CLI configured
- Terraform >= 1.0.0

## Deployment

```bash
# Navigate to terraform directory
cd terraform

# Copy and configure variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your email address
vim terraform.tfvars

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
Important: After deployment, check your email and confirm the SNS subscription.
```


## Testing

```bash
# Generate test errors
aws lambda invoke --function-name test-error-generator --region us-east-1 response.json
```


# View error processor logs
```bash
aws logs tail /aws/lambda/error-processor --region us-east-1 --since 5m
```

## Expected Output

```bash
[INFO] Excluding log entry - matched pattern: request rate is too high
[INFO] Sending notification for 2 error(s) (excluded 1)
[INFO] Notification sent successfully
```

# Cleanup
```bash
cd terraform
terraform destroy
```

## References
AWS Blog: ![Get notified for specific Lambda function error patterns using CloudWatch](https://aws.amazon.com/blogs/mt/get-notified-specific-lambda-function-error-patterns-using-cloudwatch/)