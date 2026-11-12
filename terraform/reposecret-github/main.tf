variable "path" {
  description = "OpenBao logical KV path containing the source secret (for example onprem/dynamic/vault-root)."
  type        = string
}

variable "property" {
  description = "Property in the Vault secret containing the value to copy."
  type        = string
}

variable "org" {
  description = "Repository owner override. Defaults to the GitHub username in OpenBao."
  type        = string
  default     = null
}

variable "repository" {
  description = "Existing repository name, without the owner prefix."
  type        = string
}

variable "name" {
  description = "Name of the GitHub repository Actions and Dependabot secret."
  type        = string
}

data "vault_generic_secret" "source" {
  path = var.path
}

resource "github_actions_secret" "secret" {
  repository      = var.repository
  secret_name     = var.name
  plaintext_value = data.vault_generic_secret.source.data[var.property]
}

resource "github_dependabot_secret" "secret" {
  repository      = var.repository
  secret_name     = var.name
  plaintext_value = data.vault_generic_secret.source.data[var.property]
}
