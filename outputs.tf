output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state for this account. Use in every consumer repo's backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_dr_name" {
  description = "Name of the DR-region state bucket. Null if CRR is disabled."
  value       = local.enable_crr ? aws_s3_bucket.state_dr[0].id : null
}

output "lock_table_name" {
  description = "DynamoDB table name used for Terraform state locking."
  value       = aws_dynamodb_table.lock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting state at rest."
  value       = aws_kms_key.state.arn
}

output "kms_key_alias" {
  description = "Alias for the state KMS key. Use this in backend.hcl as kms_key_id (alias is portable across regions)."
  value       = aws_kms_alias.state.name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role consumer CI workflows assume via OIDC."
  value       = aws_iam_role.github_actions_terraform.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in this account."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "audit_trail_arn" {
  description = "ARN of the CloudTrail trail capturing state-bucket data events."
  value       = aws_cloudtrail.state_audit.arn
}

# ---------------------------------------------------------------------------
# Convenience block: copy/paste into a consumer's backend.hcl
# ---------------------------------------------------------------------------
output "backend_hcl_snippet" {
  description = "Drop-in backend.hcl content for consumer repos."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    key            = "<project>/<env>/<service>/terraform.tfstate"
    region         = "${var.region}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    encrypt        = true
    kms_key_id     = "${aws_kms_alias.state.name}"
  EOT
}
