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
      version = "5.13.0"
    }
  }
}

# The runner logs in as onpremise only to read its bootstrap records.
provider "vault" {
  skip_child_token = true
  auth_login_userpass {}
}

variable "admin_input" {
  description = "Logical OpenBao KV path containing the admin token and internal URL."
  type        = string
  default     = "onprem/dynamic/vault-root"
}

data "vault_generic_secret" "admin" {
  path = var.admin_input

  lifecycle {
    postcondition {
      condition     = alltrue([for key in ["token", "url"] : try(length(trimspace(self.data[key])) > 0, false)])
      error_message = "admin_input must contain nonempty token and url properties."
    }
  }
}

# Auth methods, identities and ACL policies require the existing admin policy.
# VAULT_CACERT supplies TLS trust for both providers.
provider "vault" {
  alias            = "admin"
  address          = data.vault_generic_secret.admin.data["url"]
  token            = data.vault_generic_secret.admin.data["token"]
  skip_child_token = true
}

