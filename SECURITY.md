# Security policy

## Reporting a vulnerability

Email `security@devotica.com` with `[terraform-bootstrap-template]` in the subject. Include:

- A description of the issue
- The affected resource(s) or trust-policy component
- Steps to reproduce
- Affected version / commit SHA
- Your assessment of impact (this repo creates IAM trust policies — bypasses are HIGH severity)

You will receive an acknowledgement within 2 business days. We follow a 90-day responsible disclosure policy.

## Particularly sensitive areas

- **OIDC trust policy** in `main.tf` — a wildcard or overly permissive subject claim could let arbitrary GitHub repos assume the role
- **KMS key policy** — allowing the wrong principal could leak state at rest
- **State bucket policy** — a hole here lets state files be read by unintended principals

## Out of scope

- Issues in the AWS provider — please report to https://github.com/hashicorp/terraform-provider-aws
- Issues in sops / age — please report upstream
- Per-account instance repos — those have their own SECURITY.md

## Supported versions

The latest minor version of each major series receives security updates.
