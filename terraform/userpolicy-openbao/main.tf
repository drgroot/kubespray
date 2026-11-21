variable "name" {
  description = "Unique name for this additive policy workspace."
  type        = string
}

variable "username" {
  description = "Username managed by user-openbao to receive this policy."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", var.username))
    error_message = "username must be a nonempty user name using letters, digits, dots, underscores or hyphens; consecutive hyphens are reserved."
  }
  validation {
    condition     = !strcontains(var.username, "--")
    error_message = "Consecutive hyphens are reserved for the policy owner delimiter."
  }
}

variable "path" {
  description = "Comma-separated OpenBao API paths authorized by this policy."
  type        = string

  validation {
    condition     = alltrue([for path in split(",", var.path) : trimspace(path) != ""])
    error_message = "path must contain nonempty comma-separated API paths."
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
    error_message = "capabilities must contain valid OpenBao policy capabilities."
  }
}

locals {
  policy_paths        = distinct([for path in split(",", var.path) : trimspace(path)])
  policy_capabilities = distinct([for capability in split(",", var.capabilities) : trimspace(capability)])
}

# user-openbao discovers this exact username prefix and adds these policies to
# its account and token on reconciliation. This workspace owns only its policy;
# it never writes credentials, identity records or shared attachment lists.
resource "vault_policy" "user" {
  provider = vault.admin
  name     = "openbao-userpolicy-${var.username}--${var.name}"
  policy = join("\n", [for path in local.policy_paths : <<-EOT
    path ${jsonencode(path)} {
      capabilities = ${jsonencode(local.policy_capabilities)}
    }
  EOT
  ])
}
