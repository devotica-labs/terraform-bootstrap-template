###############################################################################
# Provider configuration
###############################################################################
provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

# Secondary provider for the DR region. Configured even when CRR is disabled
# (so Terraform can resolve the alias), but no resources actually use it then.
provider "aws" {
  alias  = "dr"
  region = var.dr_region == null ? var.region : var.dr_region
  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

###############################################################################
# KMS key — encrypts state at rest and CloudTrail logs
###############################################################################
resource "aws_kms_key" "state" {
  description             = "Encrypts Terraform state for account ${var.account_id}"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  policy = data.aws_iam_policy_document.kms_state_policy.json

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-terraform-state"
  })
}

resource "aws_kms_alias" "state" {
  name          = local.kms_alias_name
  target_key_id = aws_kms_key.state.key_id
}

data "aws_iam_policy_document" "kms_state_policy" {
  # Account root retains administrative access (break-glass)
  statement {
    sid    = "AccountRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # The OIDC role uses the key for state encryption/decryption.
  statement {
    sid    = "TerraformOidcRoleUse"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.account_id}:role/${local.github_actions_role}"]
    }
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }

  # CloudTrail uses the key to encrypt the trail's S3 objects.
  statement {
    sid    = "CloudTrailEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = [
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${data.aws_partition.current.partition}:cloudtrail:*:${var.account_id}:trail/*"]
    }
  }
}

###############################################################################
# State bucket — primary
###############################################################################
resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket_name
  force_destroy = false

  tags = merge(local.tags, {
    Name = local.state_bucket_name
  })
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {} # apply to entire bucket

    noncurrent_version_expiration {
      noncurrent_days = var.state_lifecycle_noncurrent_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket_policy.json
}

data "aws_iam_policy_document" "state_bucket_policy" {
  # Force TLS on every request — RBI / SOC 2 baseline.
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Force objects to use the bootstrap KMS key — no SSE-S3 fallback.
  statement {
    sid       = "DenyUnencryptedPut"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
}

###############################################################################
# State bucket — server access logging target
###############################################################################
resource "aws_s3_bucket" "state_logs" {
  bucket        = local.state_bucket_logs_name
  force_destroy = false

  tags = merge(local.tags, {
    Name = local.state_bucket_logs_name
  })
}

resource "aws_s3_bucket_versioning" "state_logs" {
  bucket = aws_s3_bucket.state_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_logs" {
  bucket = aws_s3_bucket.state_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state_logs" {
  bucket                  = aws_s3_bucket.state_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.state_logs.id
  target_prefix = "tfstate-access/"
}

###############################################################################
# State bucket — DR replica (optional)
###############################################################################
resource "aws_s3_bucket" "state_dr" {
  count    = local.enable_crr ? 1 : 0
  provider = aws.dr

  bucket        = local.state_bucket_dr_name
  force_destroy = false

  tags = merge(local.tags, {
    Name = local.state_bucket_dr_name
  })
}

resource "aws_s3_bucket_versioning" "state_dr" {
  count    = local.enable_crr ? 1 : 0
  provider = aws.dr

  bucket = aws_s3_bucket.state_dr[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state_dr" {
  count    = local.enable_crr ? 1 : 0
  provider = aws.dr

  bucket                  = aws_s3_bucket.state_dr[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "replication" {
  count = local.enable_crr ? 1 : 0

  name               = "${var.name_prefix}-tfstate-replication"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "replication" {
  count = local.enable_crr ? 1 : 0

  name   = "${var.name_prefix}-tfstate-replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

data "aws_iam_policy_document" "replication" {
  count = local.enable_crr ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]
    resources = ["${aws_s3_bucket.state_dr[0].arn}/*"]
  }
}

resource "aws_s3_bucket_replication_configuration" "state" {
  count = local.enable_crr ? 1 : 0

  depends_on = [aws_s3_bucket_versioning.state]

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "replicate-state-to-dr"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.state_dr[0].arn
      storage_class = "STANDARD_IA"
    }
  }
}

###############################################################################
# DynamoDB lock table
###############################################################################
resource "aws_dynamodb_table" "lock" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state.arn
  }

  tags = merge(local.tags, {
    Name = local.lock_table_name
  })
}

###############################################################################
# IAM OIDC provider for GitHub Actions
###############################################################################
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.oidc_provider_url}"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's TLS root CA thumbprint. AWS no longer strictly validates this list
  # (since 2023) but the field is still required.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-github-oidc"
  })
}

###############################################################################
# IAM role assumed by GitHub Actions
###############################################################################
resource "aws_iam_role" "github_actions_terraform" {
  name = local.github_actions_role

  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = 3600 # 1 hour, no exceptions

  tags = merge(local.tags, {
    Name = local.github_actions_role
  })
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Audience claim — always sts.amazonaws.com for GitHub Actions OIDC.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Subject claim — scoped to specific repo + ref/environment combinations.
    # NEVER use a wildcard like 'repo:org/*:*' (Foundation Plan §6.4).
    condition {
      test     = "StringLike"
      variable = "${local.oidc_provider_url}:sub"
      values   = var.allowed_repos
    }
  }
}

# Note: this role intentionally has NO managed policy attached by default.
# Each consumer adds the AWS-managed or customer-managed policies it actually
# needs (via a separate Terraform run, or out-of-band by the account owner).
# Foundation Plan §11.5 — least-privilege, reviewed.

###############################################################################
# CloudTrail data events on the state bucket
###############################################################################
resource "aws_cloudtrail" "state_audit" {
  name                          = local.cloudtrail_trail_name
  s3_bucket_name                = aws_s3_bucket.state_logs.id
  s3_key_prefix                 = "cloudtrail/"
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.state.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type = "AWS::S3::Object"
      values = [
        "${aws_s3_bucket.state.arn}/",
      ]
    }
  }

  tags = merge(local.tags, {
    Name = local.cloudtrail_trail_name
  })

  depends_on = [aws_s3_bucket_policy.state_logs_for_cloudtrail]
}

resource "aws_s3_bucket_policy" "state_logs_for_cloudtrail" {
  bucket = aws_s3_bucket.state_logs.id
  policy = data.aws_iam_policy_document.state_logs_for_cloudtrail.json
}

data "aws_iam_policy_document" "state_logs_for_cloudtrail" {
  statement {
    sid     = "AWSCloudTrailAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = [aws_s3_bucket.state_logs.arn]
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.state_logs.arn}/cloudtrail/AWSLogs/${var.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}
