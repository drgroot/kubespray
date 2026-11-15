variable "credentialpath" {
  type = string
}

variable "passwordkey" {
  type = string
}

variable "usernamekey" {
  description = "Optional credential property containing the username; defaults to name."
  type        = string
  default     = null
}

variable "gitea_url" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.credentialpath
}

provider "gitea" {
  base_url = var.gitea_url
  username = local.gitea_username
  password = data.vault_generic_secret.credentials.data[var.passwordkey]
}
