# Changelog

All notable changes to this template are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the template
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Releases are cut automatically by `release-please` on merge to `main`,
driven by Conventional Commit prefixes (`feat:` → minor, `fix:`/`docs:`/`chore:` → patch,
`feat!:` or `BREAKING CHANGE:` footer → major).

## [1.0.1](https://github.com/devotica-labs/terraform-bootstrap-template/compare/v1.0.0...v1.0.1) (2026-06-16)


### Bug Fixes

* **ci:** remove unused data source + switch gitleaks to OSS binary ([#6](https://github.com/devotica-labs/terraform-bootstrap-template/issues/6)) ([af7cfd2](https://github.com/devotica-labs/terraform-bootstrap-template/commit/af7cfd2efd4ae7b07f20319ad6d9973d26f7d7ac))
* **ci:** remove unused data source + switch gitleaks to OSS binary ([#7](https://github.com/devotica-labs/terraform-bootstrap-template/issues/7)) ([d8414d9](https://github.com/devotica-labs/terraform-bootstrap-template/commit/d8414d92a990a390333dba6b0d68bce5143f1bcb))

## [Unreleased]

### Added
- Apache-2.0 NOTICE file (pairs with LICENSE).
- Contributor Covenant v2.1 CODE_OF_CONDUCT.md.
- Initial CHANGELOG.md following Keep a Changelog.
- `.github/pull_request_template.md` matching the module-repo template.
- `.github/workflows/release.yml` — release-please for cutting versioned tags
  of the template structure itself.
- `.pre-commit-config.yaml` (terraform_fmt, terraform_validate, terraform_docs,
  tflint, tfsec, gitleaks, basic hooks).
- `.tflint.hcl` with the AWS plugin and the same rule set every Devotica
  module pins.
