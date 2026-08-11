variable "credentialpath" {
  type = string
}

variable "usernamekey" {
  type = string
}

variable "passwordkey" {
  type = string
}

variable "gitea_url" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.credentialpath
}

provider "gitea" {
  base_url = var.gitea_url
  username = data.vault_generic_secret.credentials.data[var.usernamekey]
  password = data.vault_generic_secret.credentials.data[var.passwordkey]
}
