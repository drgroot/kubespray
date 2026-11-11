variable "credentialpath" {
  description = "Vault KV path containing the GitHub username and token used to manage the repository secret."
  type        = string
}

variable "usernamekey" {
  description = "Property in credentialpath containing the GitHub username."
  type        = string
}

variable "tokenkey" {
  description = "Property in credentialpath containing the GitHub token."
  type        = string
}

data "vault_generic_secret" "credentials" {
  path = var.credentialpath
}

provider "github" {
  owner = coalesce(var.org, data.vault_generic_secret.credentials.data[var.usernamekey])
  token = data.vault_generic_secret.credentials.data[var.tokenkey]
}
