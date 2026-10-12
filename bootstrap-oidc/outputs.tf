output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "plan_role_arn" {
  description = "ARN of the read-only role for terraform plan (empty when disabled)"
  value       = join("", aws_iam_role.plan[*].arn)
}

output "apply_role_arn" {
  description = "ARN of the write role for terraform apply (empty when disabled)"
  value       = join("", aws_iam_role.apply[*].arn)
}

output "allowed_subjects" {
  description = "Subject claims the plan role trusts"
  value       = local.allowed_subjects
}
