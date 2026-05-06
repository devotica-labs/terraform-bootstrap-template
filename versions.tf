terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30"
    }
  }

  # Local backend on first run (so we can create the S3 bucket that backs
  # subsequent runs). After apply, encrypt terraform.tfstate via sops and
  # commit it. See README "First run" section.
  backend "local" {
    # path is set per-account via -backend-config=state/<account>.local.hcl
    # so that one repo can manage many accounts without state collision.
  }
}
