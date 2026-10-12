terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Owner     = var.owner
  }

  oidc_host = "token.actions.githubusercontent.com"

  # Scope every trust policy to this repository. The :* suffix is what allows
  # any branch, tag, or pull request context to assume the role.
  allowed_subjects = [
    for prefix in var.allowed_subject_prefixes :
    "repo:${var.github_org}/${var.github_repo}:${prefix}"
  ]
}
