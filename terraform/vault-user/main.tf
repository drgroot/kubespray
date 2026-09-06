variable "name" {
  description = "Name used for the Vault policy."
  type        = string
}

variable "input" {
  description = "Vault KV path containing the userpass credentials and Vault address."
  type        = string
}

variable "output" {
  description = "Vault KV path where the generated user credentials are written."
  type        = string
}

variable "usernamekey" {
  type = string
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

variable "vault_addr" {
  description = "External Vault address written to the output secret."
  type        = string
}

variable "path" {
  description = "Vault API path authorized by the generated policy."
  type        = string
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

data "vault_generic_secret" "input" {
  path = var.input
}

locals {
  username            = data.vault_generic_secret.input.data[var.usernamekey]
  password            = data.vault_generic_secret.input.data[var.passwordkey]
  policy_capabilities = [for capability in split(",", var.capabilities) : trimspace(capability)]
}

resource "vault_policy" "user" {
  name = "vault-user-${var.name}"

  policy = <<-EOT
    path ${jsonencode(var.path)} {
      capabilities = ${jsonencode(local.policy_capabilities)}
    }

    # The Terraform Vault provider uses this endpoint to mint its limited
    # child token before managing Vault resources.
    path "auth/token/create" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_generic_endpoint" "userpass_user" {
  path                 = "auth/userpass/users/${local.username}"
  ignore_absent_fields = true
  data_json = jsonencode({
    password = local.password
    policies = [vault_policy.user.name]
  })
}

resource "vault_token" "user" {
  policies = [vault_policy.user.name]
}
