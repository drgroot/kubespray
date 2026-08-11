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
      version = "5.10.1"
    }

    b2 = {
      source  = "Backblaze/b2"
      version = "0.13.2"
    }
  }
}

provider "vault" {

}