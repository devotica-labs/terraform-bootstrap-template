# Contributing

Issues are welcome from anyone. Pull requests at this time are accepted only from members of the Devotica engineering team while the catalog stabilises.

## For Devotica engineers

### Workflow

1. Fork or create a branch
2. Run `pre-commit install` (uses canonical hooks from terraform-shared-config)
3. Make your changes — keep `main.tf` strictly account-agnostic; account-specific values go in `accounts/*.tfvars`
4. Run locally:
   ```bash
   terraform fmt -check -recursive
   terraform init -backend=false
   terraform validate
   tflint --init && tflint
   ```
5. Open a PR — CI re-runs all four checks

### What belongs in this repo vs. an instance

This is the **template**. It must be account-agnostic.

| Belongs here (template) | Belongs in an instance repo |
|---|---|
| HCL that takes `var.account_id`, `var.region`, etc. | The actual account_id values |
| `accounts/example.tfvars` (placeholders) | `accounts/<account-name>.tfvars` (real) |
| `state/.keep` | `state/<account-name>.tfstate.encrypted` |
| Documentation, runbooks | Per-account decisions in CHANGELOG / ADRs |

If you're tempted to commit something like `account_id = "123456789012"` (a real 12-digit AWS account ID) here, stop. That goes in the instance repo.

### Adding a resource

1. Add the resource to `main.tf`
2. Add tags via `merge(local.tags, { Name = ... })`
3. If it accepts encryption, ensure it uses `aws_kms_key.state.arn`
4. Add an output to `outputs.tf` if downstream consumers will reference it
5. Update the README's "What gets created" table
6. Major bump if the new resource changes downstream addresses

### Conventional commits

```
feat: add CloudWatch alarms on state bucket size
fix: correct OIDC thumbprint for GitHub's new TLS chain
docs: clarify the age-vs-KMS trade-off for sops
feat!: rename github_actions_role from "GitHubActions" to "GitHubActionsTerraform"
```

## Reporting security issues

Don't open a public issue. Email `security@devotica.com` with `[terraform-bootstrap-template]` in the subject.
