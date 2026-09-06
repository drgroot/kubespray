variable "name" {
  description = "Authelia subject and Vault identity entity name."
  type        = string

  validation {
    condition     = trimspace(var.name) != ""
    error_message = "name must not be empty."
  }
}

# Accepted for compatibility with the shared Crossplane Workspace interface.
# OIDC access policies do not read an input secret or write an output secret.
variable "input" {
  type    = string
  default = ""
}

variable "output" {
  type    = string
  default = ""
}

variable "path" {
  description = "Vault API path to authorize, for example external-infra/data/authelia/salihah."
  type        = string

  validation {
    condition     = trimspace(var.path) != ""
    error_message = "path must not be empty."
  }
}

variable "capabilities" {
  description = "Comma-separated Vault policy capabilities for path."
  type        = string

  validation {
    condition = alltrue([
      for capability in split(",", var.capabilities) :
      contains(["create", "read", "update", "patch", "delete", "list", "sudo", "deny"], trimspace(capability))
    ])
    error_message = "capabilities must be a comma-separated list of valid Vault policy capabilities."
  }
}

variable "oidc_mount" {
  description = "Vault auth mount configured for Authelia OIDC."
  type        = string
  default     = "oidc"
}

variable "manage_identity" {
  description = "Whether this workspace owns the user's Vault identity entity and OIDC alias."
  type        = bool
  default     = true
}

locals {
  policy_capabilities = [for capability in split(",", var.capabilities) : trimspace(capability)]
}

data "vault_auth_backend" "oidc" {
  path = var.oidc_mount
}

data "vault_identity_entity" "user" {
  count = var.manage_identity ? 0 : 1

  entity_name = var.name
}

resource "vault_policy" "user_path" {
  name = "oidc-${var.name}-${replace(var.path, "/", "-")}"

  policy = <<-EOT
    path ${jsonencode(var.path)} {
      capabilities = ${jsonencode(local.policy_capabilities)}
    }
  EOT
}

resource "vault_identity_entity" "user" {
  count = var.manage_identity ? 1 : 0

  name              = var.name
  external_policies = true
}

locals {
  entity_id = var.manage_identity ? vault_identity_entity.user[0].id : data.vault_identity_entity.user[0].id
}

resource "vault_identity_entity_policies" "user_path" {
  entity_id = local.entity_id
  policies  = [vault_policy.user_path.name]
  exclusive = false
}

resource "vault_identity_entity_alias" "authelia" {
  count = var.manage_identity ? 1 : 0

  name           = var.name
  mount_accessor = data.vault_auth_backend.oidc.accessor
  canonical_id   = local.entity_id
}
