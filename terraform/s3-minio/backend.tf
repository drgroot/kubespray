terraform {
  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.40.1"
    }

    vault = {
      source  = "hashicorp/vault"
      version = "5.10.1"
    }
  }
}

provider "vault" {

}
