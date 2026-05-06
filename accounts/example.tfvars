# Example tfvars file. Copy this to <account-name>.tfvars and customise.
#
# DO NOT commit a tfvars file containing a real account_id under accounts/
# unless the repo is in the correct GitHub org (per the multi-tenant model).
#   - devotica-labs/devotica-sandbox-bootstrap → accounts/sandbox.tfvars (Devotica's own account)
#   - <client>/terraform-bootstrap            → accounts/dev.tfvars / prod.tfvars (client account)

# ----- Required inputs -----

account_id = "111122223333"      # 12-digit AWS account ID
region     = "ap-south-1"        # primary region; ap-south-1 for fintech / India localization
github_org = "<your-github-org>" # e.g. "devotica-labs" or the client's org

# Whitelist of GitHub repo + ref/environment claims allowed to assume the
# GitHubActionsTerraform role. ALWAYS scope explicitly per repo+branch or
# repo+environment. NEVER use a wildcard like 'repo:org/*:*'.
allowed_repos = [
  "repo:<your-github-org>/sample-infra:ref:refs/heads/main",
  "repo:<your-github-org>/sample-infra:environment:dev",
  # Module integration tests in the Sandbox:
  "repo:<your-github-org>/terraform-aws-vpc:environment:integration",
  "repo:<your-github-org>/terraform-aws-iam-role:environment:integration",
  # Add more as new modules / projects come online.
]

# ----- Optional inputs (sensible defaults) -----

dr_region                       = "ap-southeast-1" # null disables CRR (not recommended in prod)
name_prefix                     = "devotica"       # change to "otpless", "protectt", etc. for client accounts
kms_key_deletion_window         = 30
state_lifecycle_noncurrent_days = 90

# Extra tags merged on top of the mandatory six. CostCenter, Environment etc.
# are automatically populated from name_prefix.
tags = {
  # DataClassification = "internal"
  # Compliance         = "RBI,SOC2"
}
