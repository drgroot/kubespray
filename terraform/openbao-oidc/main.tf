variable "name" {
  description = "OpenBao identity entity name, usually the Authelia username."
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
  description = "Comma-separated OpenBao API paths to authorize with the same capabilities, for example onprem/data/authelia/*,onprem/metadata/authelia/*. Whitespace is trimmed."
  type        = string

  validation {
    condition     = alltrue([for path in split(",", var.path) : trimspace(path) != ""])
    error_message = "path must contain one or more comma-separated paths with no empty entries."
  }
}

variable "capabilities" {
  description = "Comma-separated OpenBao policy capabilities for path."
  type        = string

  validation {
    condition = alltrue([
      for capability in split(",", var.capabilities) :
      contains(["create", "read", "update", "patch", "delete", "list", "sudo", "deny"], trimspace(capability))
    ])
    error_message = "capabilities must be a comma-separated list of valid OpenBao policy capabilities."
  }
}

variable "oidc_mount" {
  description = "OpenBao auth mount configured for Authelia OIDC."
  type        = string
  default     = "oidc"
}

variable "manage_identity" {
  description = "Whether this workspace owns the user's named identity, external group, and OIDC group alias."
  type        = bool
  default     = true
}

locals {
  policy_paths        = distinct([for path in split(",", var.path) : trimspace(path)])
  policy_path_name    = join("--", [for path in local.policy_paths : replace(replace(path, "*", ""), "/", "-")])
  policy_capabilities = [for capability in split(",", var.capabilities) : trimspace(capability)]
}

data "vault_auth_backend" "oidc" {
  provider = vault.admin
  path     = var.oidc_mount
}

data "vault_identity_entity" "user" {
  provider = vault.admin
  count    = var.manage_identity ? 0 : 1

  entity_name = var.name
}

resource "vault_policy" "user_path" {
  provider = vault.admin
  name     = "oidc-${var.name}-${local.policy_path_name}"

  policy = join("\n", [for path in local.policy_paths : <<-EOT
    path ${jsonencode(path)} {
      capabilities = ${jsonencode(local.policy_capabilities)}
    }
  EOT
  ])
}

resource "vault_identity_entity" "user" {
  provider = vault.admin
  count    = var.manage_identity ? 1 : 0

  name              = var.name
  external_policies = true
}

locals {
  entity_id = var.manage_identity ? vault_identity_entity.user[0].id : data.vault_identity_entity.user[0].id
}

resource "vault_identity_entity_policies" "user_path" {
  provider  = vault.admin
  entity_id = local.entity_id
  policies  = [vault_policy.user_path.name]
  exclusive = false
}

# Username aliases cannot match the OIDC sub UUID. External groups instead
# map the authenticated preferred_username claim to per-user policies.
data "vault_identity_group" "user" {
  provider = vault.admin
  count    = var.manage_identity ? 0 : 1

  group_name = "oidc-${var.oidc_mount}-${var.name}"
}

resource "vault_identity_group" "user" {
  provider = vault.admin
  count    = var.manage_identity ? 1 : 0

  name              = "oidc-${var.oidc_mount}-${var.name}"
  type              = "external"
  external_policies = true
}

locals {
  group_id = var.manage_identity ? vault_identity_group.user[0].id : data.vault_identity_group.user[0].group_id
}

resource "vault_identity_group_policies" "user_path" {
  provider  = vault.admin
  group_id  = local.group_id
  policies  = [vault_policy.user_path.name]
  exclusive = false
}

resource "vault_identity_group_alias" "authelia" {
  provider = vault.admin
  count    = var.manage_identity ? 1 : 0

  name           = var.name
  mount_accessor = data.vault_auth_backend.oidc.accessor
  canonical_id   = local.group_id
}
