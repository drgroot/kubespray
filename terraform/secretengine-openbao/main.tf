variable "name" {
  description = "Path of the KV v2 secrets engine to create."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_.-]*$", var.name))
    error_message = "name must be a nonempty mount name without slashes."
  }
}

variable "input" {
  description = "Logical KV v2 path containing username, token, url, and ca-cert (for example onprem/dynamic/vault-root)."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+(/[^/]+)*$", var.input))
    error_message = "input must be a logical KV v2 path in mount/secret form, without the API's /data/ segment."
  }
}

variable "output" {
  description = "Optional logical KV v2 path to publish the input owner's credentials after creating the engine; none disables publishing."
  type        = string
  default     = "none"

  validation {
    condition     = var.output == "none" || can(regex("^[^/]+/[^/]+(/[^/]+)*$", var.output))
    error_message = "output must be none or a logical KV v2 path in mount/secret form."
  }
}

locals {
  input_segments  = split("/", var.input)
  output_segments = split("/", var.output)
}

data "vault_kv_secret_v2" "input" {
  mount = local.input_segments[0]
  name  = join("/", slice(local.input_segments, 1, length(local.input_segments)))

  lifecycle {
    postcondition {
      condition = alltrue([
        for key in ["username", "token", "url", "ca-cert"] :
        try(length(trimspace(self.data[key])) > 0, false)
      ])
      error_message = "The input record must contain nonempty username, token, url, and ca-cert properties from the root PushSecret."
    }
  }
}

resource "vault_mount" "engine" {
  provider    = vault.admin
  path        = var.name
  type        = "kv"
  description = "KV v2 secrets engine managed for ${var.name}."
  options = {
    version = "2"
  }
}

# The input owner's existing admin token remains valid for the new engine.
# Do not replace the shared openbao-admin policy with a mount-specific policy.
resource "vault_kv_secret_v2" "output" {
  provider = vault.admin
  count    = var.output == "none" ? 0 : 1

  mount = local.output_segments[0]
  name  = join("/", slice(local.output_segments, 1, length(local.output_segments)))
  data_json = jsonencode({
    for key in ["username", "token", "url", "ca-cert"] :
    key => data.vault_kv_secret_v2.input.data[key]
  })

  depends_on = [vault_mount.engine]
}
