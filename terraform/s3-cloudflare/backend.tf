terraform {
  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.28.1"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
  }
}

provider "vault" {
  skip_child_token = true
  auth_login_userpass {}
}
