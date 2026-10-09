variable "path" {
  description = "Vault KV path containing the source secret (for example external-infra/iac/deploy)."
  type        = string
}

variable "property" {
  description = "Property in the Vault secret containing the value to copy."
  type        = string
}

variable "org" {
  description = "Existing Gitea organization that will own the Actions secret."
  type        = string
}

variable "name" {
  description = "Name of the Gitea organization Actions secret."
  type        = string
}

data "vault_generic_secret" "source" {
  path = var.path
}

resource "gitea_org_actions_secret" "secret" {
  org          = var.org
  secret_name  = var.name
  secret_value = data.vault_generic_secret.source.data[var.property]
}
