variable "gitea_url" {
  description = "Gitea base URL, without the /api/v1 suffix."
  type        = string
}

variable "credentialpath" {
  description = "Vault KV path containing the Gitea username and password used to manage the organization secret."
  type        = string
}

variable "usernamekey" {
  description = "Property in credentialpath containing the Gitea username."
  type        = string
}

variable "passwordkey" {
  description = "Property in credentialpath containing the Gitea password."
  type        = string
}

data "vault_generic_secret" "credentials" {
  path = var.credentialpath
}

provider "gitea" {
  base_url = var.gitea_url
  username = data.vault_generic_secret.credentials.data[var.usernamekey]
  password = data.vault_generic_secret.credentials.data[var.passwordkey]
}
