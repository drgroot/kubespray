variable "name" {
  description = "Name used for the OpenBao policy."
  type        = string
}

variable "input" {
  description = "OpenBao KV path containing the password and optional username."
  type        = string
}

variable "output" {
  description = "OpenBao KV path where the generated user credentials are written."
  type        = string
}

variable "usernamekey" {
  description = "Optional username property in input. Defaults to name when omitted."
  type        = string
  default     = null
}

variable "passwordkey" {
  type = string
}

# Accepted for compatibility with the Workspace interface. The module creates
# a new token and writes it to the output secret as the `token` property.
variable "tokenkey" {
  type    = string
  default = ""
}

variable "openbao_addr" {
  description = "External OpenBao address written to the output secret."
  type        = string
}

variable "path" {
  description = "OpenBao API path authorized by the generated policy."
  type        = string
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

data "vault_generic_secret" "input" {
  path = var.input
}

locals {
  username            = var.usernamekey == null ? var.name : data.vault_generic_secret.input.data[var.usernamekey]
  password            = data.vault_generic_secret.input.data[var.passwordkey]
  policy_capabilities = [for capability in split(",", var.capabilities) : trimspace(capability)]
}

resource "vault_policy" "user" {
  provider = vault.admin
  name     = "openbao-user-${var.name}"

  policy = <<-EOT
    path ${jsonencode(var.path)} {
      capabilities = ${jsonencode(local.policy_capabilities)}
    }

    # The Terraform OpenBao provider uses this endpoint to mint its limited
    # child token before managing OpenBao resources.
    path "auth/token/create" {
      capabilities = ["update"]
    }

    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

resource "vault_generic_endpoint" "userpass_user" {
  provider             = vault.admin
  path                 = "auth/userpass/users/${local.username}"
  ignore_absent_fields = true
  data_json = jsonencode({
    password = local.password
    policies = [vault_policy.user.name]
  })
}

resource "vault_token" "user" {
  provider = vault.admin
  policies = [vault_policy.user.name]

  no_parent = true
  renewable = true
  period    = "24h"

  renew_min_lease = 43200 # Renew if < 12 hours remain
  renew_increment = 86400 # Request 24 hours

  display_name = "openbao-user-${var.name}"
}
