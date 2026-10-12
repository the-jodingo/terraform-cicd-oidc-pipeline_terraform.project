variable "aws_region" {
  description = "AWS region for the deployment roles"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and role naming"
  type        = string
  default     = "cicd"
}

variable "owner" {
  description = "Team or individual accountable for these resources"
  type        = string
  default     = "platform-team"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "Repository allowed to assume the deployment roles"
  type        = string
}

variable "allowed_subject_prefixes" {
  description = "Subject claim prefixes allowed to assume the plan role"
  type        = list(string)
  default     = ["pull_request", "ref:refs/heads/main"]
}

variable "apply_subject_prefixes" {
  description = "Subject claim prefixes allowed to assume the apply role (keep this narrow)"
  type        = list(string)
  default     = ["ref:refs/heads/main"]
}

variable "create_plan_role" {
  description = "Create a read-only role for plan runs"
  type        = bool
  default     = true
}

variable "create_apply_role" {
  description = "Create a write role for apply runs on the protected branch"
  type        = bool
  default     = true
}

variable "plan_policy_arns" {
  description = "Additional managed policies attached to the plan role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}

variable "apply_policy_arns" {
  description = "Additional managed policies attached to the apply role"
  type        = list(string)
  default = [
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
  ]
}

variable "state_bucket_name" {
  description = "State bucket the apply role is granted read/write access to; empty disables the policy"
  type        = string
  default     = ""
}

variable "lock_table_name" {
  description = "DynamoDB lock table name used by the state access policy"
  type        = string
  default     = "terraform-state-locks"
}

variable "max_session_duration" {
  description = "Maximum session length in seconds for the deployment roles"
  type        = number
  default     = 3600
}
