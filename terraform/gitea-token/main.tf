variable "name" {
  type = string
}

locals {
  gitea_username = data.vault_generic_secret.credentials.data[var.usernamekey]
}

resource "gitea_token" "user" {
  name   = "${local.gitea_username}-opentofu"
  scopes = ["all"]
}
