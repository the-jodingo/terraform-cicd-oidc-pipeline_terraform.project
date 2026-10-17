# Terraform CI/CD with Keyless AWS Authentication

[![Validate](https://github.com/the-jodingo/terraform-cicd-oidc-pipeline_terraform.project/actions/workflows/validate.yml/badge.svg)](https://github.com/the-jodingo/terraform-cicd-oidc-pipeline_terraform.project/actions/workflows/validate.yml)
[![Terraform Plan](https://github.com/the-jodingo/terraform-cicd-oidc-pipeline_terraform.project/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/the-jodingo/terraform-cicd-oidc-pipeline_terraform.project/actions/workflows/terraform-plan.yml)
[![Terraform Apply](https://github.com/the-jodingo/terraform-cicd-oidc-pipeline_terraform.project/actions/workflows/terraform-apply.yml/badge.svg)](https://github.com/the-jodingo/terraform-cicd-oidc-pipeline_terraform.project/actions/workflows/terraform-apply.yml)

A hands-on lab for running Terraform in GitHub Actions with **no stored AWS credentials**.
You will configure an OIDC trust relationship between GitHub and AWS, then build a pipeline
that plans on pull requests and applies on merge behind an approval gate.

**Who this is for:** students who have run `terraform apply` locally and now want to automate
it. You should be comfortable with git branches and pull requests.

**Time:** roughly 90 minutes.

---

## Why this matters

The most common way cloud credentials leak is a long-lived AWS access key pasted into CI
secrets. It never expires, it gets copied to laptops and printed in logs, and rotating it
breaks every pipeline that used it.

GitHub OIDC removes the key entirely. The workflow asks GitHub for a token describing the
repository, branch, and run. AWS validates that token against GitHub's certificates and hands
back credentials valid for one hour.

```
GitHub Actions  --(OIDC token)-->  AWS STS  --(1h credentials)-->  your workflow
```

The catch: the IAM trust policy is now the entire security boundary. Get it wrong and any
repository on GitHub can assume your role. This lab shows you how to scope it correctly.

---

## What you will build

```
bootstrap-oidc/          OIDC provider, plan role, apply role
infra/                   Application stack the pipeline deploys
.github/workflows/
  validate.yml               fmt, validate, TFLint, Checkov
  terraform-plan.yml         OIDC-authenticated plan on pull requests
  terraform-apply.yml        OIDC-authenticated apply on main, behind a gate
.tflint.hcl              Linter configuration
```

---

## Learning objectives

By the end you should be able to:

1. Explain how OIDC federation replaces static credentials
2. Create an IAM OIDC provider for GitHub Actions
3. Scope a trust policy to one repository and branch
4. Separate read-only plan credentials from write-capable apply credentials
5. Gate apply behind a GitHub environment with required reviewers
6. Read a Terraform plan from a workflow run summary

---

## Prerequisites

| Tool | Version | Check |
| --- | --- | --- |
| Terraform | >= 1.5 | `terraform version` |
| GitHub CLI | >= 2.40 | `gh --version` |
| AWS CLI | v2 | `aws --version` |

You need an AWS account where you can create IAM OIDC providers and roles, and a GitHub
repository you own.

```bash
gh auth status
aws sts get-caller-identity
```

Both must succeed before you continue.

---

## Step 1 — Fork or clone this repository

```bash
gh repo clone the-jodingo/terraform-cicd-oidc-pipeline_terraform.project
cd terraform-cicd-oidc-pipeline_terraform.project
```

Note your `owner/repo` slug — you need it in the next step:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

---

## Step 2 — Create the OIDC provider and roles

This is the only step needing IAM write access. Run it with an administrator profile you keep
away from CI.

```bash
cd bootstrap-oidc
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your real values:

```hcl
github_org  = "your-github-username"
github_repo = "terraform-cicd-oidc-pipeline_terraform.project"

allowed_subject_prefixes = ["pull_request", "ref:refs/heads/main"]
apply_subject_prefixes   = ["ref:refs/heads/main"]
```

Note the asymmetry: the plan role trusts pull requests and main, while the apply role trusts
**only** main. That is deliberate — see Step 5.

```bash
terraform init
terraform plan
terraform apply
```

Capture the two role ARNs:

```bash
terraform output plan_role_arn
terraform output apply_role_arn
```

---

## Step 3 — Register the role ARNs as repository variables

Use **variables**, not secrets. Role ARNs are not sensitive, and keeping them visible makes
pipeline failures far easier to debug — you can see the ARN in the log instead of a masked
asterisk.

```bash
gh variable set AWS_PLAN_ROLE_ARN  --body "$(terraform -chdir=bootstrap-oidc output -raw plan_role_arn)"
gh variable set AWS_APPLY_ROLE_ARN --body "$(terraform -chdir=bootstrap-oidc output -raw apply_role_arn)"
gh variable set AWS_REGION         --body "us-east-1"
```

Confirm:

```bash
gh variable list
```

---

## Step 4 — Gate the apply path

Create a GitHub environment named `production`:

```bash
gh api -X PUT repos/{owner}/{repo}/environments/production
```

Then in the repository: **Settings → Environments → production → Required reviewers**, and add
yourself.

The apply job declares `environment: production`, so a push to main pauses until a human
approves. Without required reviewers this is only a label — add them.

---

## Step 5 — Read the trust policy

Open `bootstrap-oidc/main.tf` and find the assume-role documents.

The critical lines are the subject conditions:

```hcl
condition {
  test     = "StringLike"
  variable = "token.actions.githubusercontent.com:sub"
  values   = local.allowed_subjects
}
```

`local.allowed_subjects` resolves to values like:

```
repo:your-username/your-repo:pull_request
repo:your-username/your-repo:ref:refs/heads/main
```

The audience condition matters just as much:

```hcl
condition {
  test     = "StringEquals"
  variable = "token.actions.githubusercontent.com:aud"
  values   = ["sts.amazonaws.com"]
}
```

Without the `sub` condition, **any** GitHub repository could assume your role. Without the
`aud` condition, a token minted for a different service could be replayed at AWS.

> **Never** widen `sub` to `repo:your-username/*` on a role that can write. That lets any
> repository you own — including ones you fork by accident — assume write credentials.

---

## Step 6 — Configure the application stack

```bash
cd ../infra
cp terraform.tfvars.example terraform.tfvars
```

Set a globally unique bucket name:

```hcl
app_data_bucket_name = "cicd-app-data-yourname-2026"
```

Edit `backend/dev.hcl` if you already created a state bucket in another lab. If you have not,
either run that lab first or create the bucket manually:

```bash
aws s3api create-bucket --bucket tfstate-yourname-2026 --region us-east-1
aws s3api put-bucket-versioning --bucket tfstate-yourname-2026 \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name terraform-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Give the apply role access to that bucket by setting `state_bucket_name` in
`bootstrap-oidc/terraform.tfvars` and re-applying.

---

## Step 7 — Open a pull request and watch the plan

```bash
cd ..
git checkout -b add-app-stack
git add infra/terraform.tfvars.example
git commit -m "Configure application stack"
git push -u origin add-app-stack

gh pr create --title "Add application stack" --body "Sets up the app data bucket and log group."
```

Watch the run:

```bash
gh run list --limit 5
gh run watch
```

The plan job:

1. assumes the plan role with `aws-actions/configure-aws-credentials` and no secrets
2. runs `terraform init -backend-config=backend/dev.hcl`
3. runs `terraform plan` and writes the output to the **run summary**
4. uploads `tfplan` as an artifact

Open the run in the browser and read the summary tab. That is where a reviewer looks first.

---

## Step 8 — Merge and approve the apply

```bash
gh pr merge --squash
```

The apply job starts, then **pauses** at the environment gate. Approve it in the Actions tab
under the pending deployment.

When it completes, the run summary shows the Terraform outputs as JSON.

Verify in AWS:

```bash
aws s3 ls | grep cicd-app-data
aws logs describe-log-groups --log-group-name-prefix "/aws/cicd"
```

---

## Step 9 — Confirm no credentials are stored

This is the whole point of the lab. Prove it:

```bash
gh secret list
```

You should see **no** AWS secrets. Then check the workflow never references a static key:

```bash
grep -rn "AWS_ACCESS_KEY\|AWS_SECRET" .github/ || echo "No static credentials referenced."
```

If that grep finds something, you have undone the exercise.

---

## Step 10 — Clean up

```bash
cd infra
terraform destroy
```

Then, to remove the IAM roles:

```bash
cd ../bootstrap-oidc
terraform destroy
```

Destroying the OIDC provider breaks every workflow in this repository until you re-apply. That
is expected and worth experiencing once.

---

## Troubleshooting

**`Error: Not authorized to perform sts:AssumeRoleWithWebIdentity`**

The subject claim does not match the trust policy. Print the actual claim by adding a debug
step to the workflow:

```yaml
- run: |
    echo "sub: $(curl -sS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | jq -r .value \
      | cut -d. -f2 | base64 -d | jq -r .sub)"
```

Compare it against `terraform output allowed_subjects`.

**`Error: Could not assume role with OIDC: Incorrect token audience`**

The workflow is missing `permissions: id-token: write`. Without it GitHub will not mint a
token at all.

**`Error: Backend initialization required`**

You edited `backend/dev.hcl`. Re-run `terraform init -backend-config=backend/dev.hcl`.

**Plan job succeeds but apply is stuck "Waiting"**

The environment has required reviewers. Approve it under **Actions → the run → Review
deployments**.

**`Error: Resource not accessible by integration`**

The workflow is missing `contents: read`. Check the `permissions` block.

**TFLint fails with `Failed to initialize plugins`**

Run `tflint --init` locally first, or confirm `setup-tflint` runs before the lint step in CI.

---

## Verification checklist

- [ ] `gh secret list` shows no AWS credentials
- [ ] `terraform output plan_role_arn` and `apply_role_arn` both print ARNs
- [ ] a pull request triggers the plan job and the summary shows the plan
- [ ] merging to main pauses at the environment gate
- [ ] approving the deployment applies the stack
- [ ] `grep -rn "AWS_ACCESS_KEY" .github/` finds nothing
- [ ] `terraform destroy` in both roots completes

---

## Further exercises

1. Add a `terraform-plan.yml` comment that posts the plan summary directly onto the pull
   request instead of only the run summary.
2. Split the apply role into per-service roles and let the workflow choose based on which
   directory changed.
3. Add a `concurrency` group so two pushes to main cannot apply at the same time.
4. Add drift detection on a nightly schedule that opens an issue when the plan is non-empty.
5. Replace the managed policies on the apply role with a least-privilege inline policy
   generated from the resources `infra/` actually creates.

---

## Requirements

- Terraform >= 1.5
- AWS provider ~> 5.0, TLS provider ~> 4.0
- GitHub CLI >= 2.40
- An AWS account where you can create an IAM OIDC provider and roles
- Repository variables: `AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`, `AWS_REGION`

## License

Released under the [MIT License](LICENSE).
