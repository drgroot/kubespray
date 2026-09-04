terraform {
  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.11.0"
    }

    ovh = {
      source  = "ovh/ovh"
      version = "2.19.0"
    }
  }
}

provider "vault" {

}
