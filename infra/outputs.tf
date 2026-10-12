output "app_data_bucket_id" {
  description = "Name of the application data bucket"
  value       = aws_s3_bucket.app_data.id
}

output "app_data_bucket_arn" {
  description = "ARN of the application data bucket"
  value       = aws_s3_bucket.app_data.arn
}

output "app_log_group_name" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.app.name
}

output "alerts_topic_arn" {
  description = "ARN of the alerting topic"
  value       = aws_sns_topic.alerts.arn
}

output "kms_key_arn" {
  description = "ARN of the customer managed key encrypting application data"
  value       = aws_kms_key.app.arn
}

output "access_logs_bucket_id" {
  description = "Name of the access logs bucket (empty when logging is disabled)"
  value       = join("", aws_s3_bucket.logs[*].id)
}
