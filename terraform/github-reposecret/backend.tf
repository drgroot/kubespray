terraform {
  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_providers {
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "5.12.0"
    }
  }
}

provider "vault" {}
