variable "credentialpath" {
  description = "OpenBao logical KV path containing the GitHub username and token."
  type        = string
}

variable "usernamekey" {
  type = string
}

variable "tokenkey" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.credentialpath
}

provider "github" {
  owner = coalesce(var.org, data.vault_generic_secret.credentials.data[var.usernamekey])
  token = data.vault_generic_secret.credentials.data[var.tokenkey]
}
