locals {
  state_bucket_name      = "${var.name_prefix}-tfstate-${var.account_id}-${var.region}"
  state_bucket_logs_name = "${var.name_prefix}-tfstate-logs-${var.account_id}-${var.region}"
  state_bucket_dr_name   = "${var.name_prefix}-tfstate-${var.account_id}-${var.dr_region}"

  lock_table_name = "${var.name_prefix}-tfstate-lock"

  kms_alias_name        = "alias/${var.name_prefix}-terraform-state"
  oidc_provider_url     = "token.actions.githubusercontent.com"
  github_actions_role   = "GitHubActionsTerraform"
  cloudtrail_trail_name = "${var.name_prefix}-tfstate-audit"

  # Mandatory tags from Foundation Plan §15.2 — applied to every taggable
  # resource the bootstrap creates. Engineers cannot omit these.
  mandatory_tags = {
    Environment = "bootstrap"
    Project     = "${var.name_prefix}-terraform-bootstrap"
    Owner       = "platform@${var.name_prefix}.com"
    CostCenter  = "PLATFORM-BOOTSTRAP"
    ManagedBy   = "Terraform"
    Repo        = "https://github.com/${var.github_org}/terraform-bootstrap-template"
  }

  tags = merge(local.mandatory_tags, var.tags)

  # Whether CRR is configured. We set this null-safe so that DR-disabled
  # bootstrap (small accounts / sandboxes) doesn't pull in the secondary region.
  enable_crr = var.dr_region != null && var.dr_region != ""
}
