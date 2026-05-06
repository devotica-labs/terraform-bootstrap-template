variable "account_id" {
  description = "12-digit AWS account ID this bootstrap targets. Becomes part of the state bucket name."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be exactly 12 digits."
  }
}

variable "region" {
  description = "Primary AWS region for the state bucket and lock table."
  type        = string
  default     = "ap-south-1"
}

variable "dr_region" {
  description = "DR region for cross-region replication of the state bucket. Set to null to disable CRR (not recommended for prod)."
  type        = string
  default     = "ap-southeast-1"
}

variable "github_org" {
  description = "GitHub org that hosts repos allowed to assume the OIDC role (e.g. 'devotica-labs' or 'otpless')."
  type        = string
}

variable "allowed_repos" {
  description = <<-EOT
    List of repo + ref scopes allowed to assume the GitHubActionsTerraform role
    via OIDC. Each entry is a string suitable for the `sub` claim, e.g.:

      "repo:devotica-labs/sample-infra:ref:refs/heads/main"
      "repo:devotica-labs/sample-infra:environment:prod"
      "repo:devotica-labs/terraform-aws-vpc:environment:integration"

    Foundation Plan §6.4 — never use a wildcard like 'repo:org/*:*'. Scope
    each repo + branch or repo + environment explicitly.
  EOT
  type        = list(string)
  validation {
    condition     = length(var.allowed_repos) > 0
    error_message = "Provide at least one allowed_repos entry."
  }
  validation {
    condition     = alltrue([for s in var.allowed_repos : startswith(s, "repo:")])
    error_message = "Every allowed_repos entry must start with 'repo:<org>/<repo>:'."
  }
}

variable "name_prefix" {
  description = "Prefix used in resource names. Default 'devotica' is fine for Devotica-owned accounts; clients should override (e.g. 'otpless')."
  type        = string
  default     = "devotica"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name_prefix))
    error_message = "name_prefix must be lowercase alphanumeric+hyphen, 2-31 chars."
  }
}

variable "kms_key_deletion_window" {
  description = "Days before scheduled KMS key deletion takes effect. Foundation Plan §11.2 requires >= 7."
  type        = number
  default     = 30
  validation {
    condition     = var.kms_key_deletion_window >= 7 && var.kms_key_deletion_window <= 30
    error_message = "kms_key_deletion_window must be between 7 and 30 (AWS allowed range)."
  }
}

variable "state_lifecycle_noncurrent_days" {
  description = "Days to retain noncurrent state versions before lifecycle expiration."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Map of tags applied to every taggable resource. The mandatory Devotica tag set (Foundation Plan §15.2) is automatically merged in."
  type        = map(string)
  default     = {}
}
