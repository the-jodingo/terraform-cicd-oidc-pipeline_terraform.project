# The OIDC provider is what makes keyless authentication possible: GitHub mints a
# short-lived token, AWS verifies it against these certificates, and no long-lived
# access key is ever stored in the repository.
data "tls_certificate" "github" {
  url = "https://${local.oidc_host}"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.oidc_host}"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = local.common_tags
}

data "aws_iam_policy_document" "plan_assume_role" {
  statement {
    sid     = "AllowGitHubActionsPlan"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values   = local.allowed_subjects
    }
  }
}

resource "aws_iam_role" "plan" {
  count = var.create_plan_role ? 1 : 0

  name                 = "${var.project_name}-terraform-plan"
  description          = "Read-only role assumed by GitHub Actions during terraform plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_assume_role.json
  max_session_duration = var.max_session_duration

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "plan" {
  count = var.create_plan_role ? length(var.plan_policy_arns) : 0

  role       = aws_iam_role.plan[0].name
  policy_arn = var.plan_policy_arns[count.index]
}

data "aws_iam_policy_document" "apply_assume_role" {
  statement {
    sid     = "AllowGitHubActionsApply"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_host}:sub"
      values = [
        for prefix in var.apply_subject_prefixes :
        "repo:${var.github_org}/${var.github_repo}:${prefix}"
      ]
    }
  }
}

resource "aws_iam_role" "apply" {
  count = var.create_apply_role ? 1 : 0

  name                 = "${var.project_name}-terraform-apply"
  description          = "Write role assumed by GitHub Actions during terraform apply on main"
  assume_role_policy   = data.aws_iam_policy_document.apply_assume_role.json
  max_session_duration = var.max_session_duration

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "apply" {
  count = var.create_apply_role ? length(var.apply_policy_arns) : 0

  role       = aws_iam_role.apply[0].name
  policy_arn = var.apply_policy_arns[count.index]
}

# Remote state access is granted separately so the deployment roles stay focused on
# the resources they manage rather than on every bucket in the account.
data "aws_iam_policy_document" "state_access" {
  count = var.state_bucket_name == "" ? 0 : 1

  statement {
    sid    = "ListStateBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }

  statement {
    sid    = "ReadWriteStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/*"]
  }

  statement {
    sid    = "LockState"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = ["arn:aws:dynamodb:${var.aws_region}:*:table/${var.lock_table_name}"]
  }
}

resource "aws_iam_role_policy" "state_access" {
  count = var.state_bucket_name == "" ? 0 : 1

  name   = "${var.project_name}-terraform-state"
  role   = aws_iam_role.apply[0].id
  policy = data.aws_iam_policy_document.state_access[0].json
}
