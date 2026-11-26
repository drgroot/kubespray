terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.14.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.6.3"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.4.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}

provider "vault" {
  skip_child_token = true
  auth_login_userpass {}
}
