terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.13.0"
    }
  }
}

# The Workspace supplies VAULT_ADDR, VAULT_CACERT, TERRAFORM_VAULT_USERNAME,
# and TERRAFORM_VAULT_PASSWORD. This user only needs to read the input record.
provider "vault" {
  skip_child_token = true

  auth_login_userpass {}
}

# The input token carries the existing openbao-admin policy, which grants
# all capabilities on every mount, including this module's new engine.
# Reuse it directly: issuing a limited child token would change its identity.
# VAULT_CACERT also supplies TLS trust for this aliased provider.
provider "vault" {
  alias            = "admin"
  address          = data.vault_kv_secret_v2.input.data["url"]
  token            = data.vault_kv_secret_v2.input.data["token"]
  skip_child_token = true
}
