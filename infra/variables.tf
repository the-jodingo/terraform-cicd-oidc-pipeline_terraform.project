variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "cicd"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Team or individual accountable for these resources"
  type        = string
  default     = "platform-team"
}

variable "app_data_bucket_name" {
  description = "Globally unique name for the application data bucket"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for the application log group"
  type        = number
  default     = 365

  validation {
    condition = contains([
      "1", "3", "5", "7", "14", "30", "60", "90", "120", "150", "180",
      "365", "400", "545", "731", "1096", "1827", "2192", "2557", "2922",
      "3288", "3653",
    ], tostring(var.log_retention_days))
    error_message = "log_retention_days must be a value CloudWatch Logs accepts."
  }
}

variable "enable_access_logging" {
  description = "Write data bucket access logs to a dedicated logging bucket"
  type        = bool
  default     = true
}

variable "access_log_expiration_days" {
  description = "Days before access log objects expire"
  type        = number
  default     = 365
}

variable "noncurrent_version_expiration_days" {
  description = "Days before noncurrent object versions in the data bucket expire"
  type        = number
  default     = 90
}

variable "bucket_size_alarm_threshold" {
  description = "Bucket size in bytes that trips the alarm"
  type        = number
  default     = 10737418240
}
