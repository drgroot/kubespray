variable "name" {
  type = string
}

# Kept for compatibility with existing Crossplane Workspace resources. User
# creation does not write an output secret; token creation is handled by the
# separate gitea-token module.
variable "output" {
  type    = string
  default = null
}

locals {
  gitea_username = data.vault_generic_secret.credentials.data[var.usernamekey]
}

resource "gitea_user" "user" {
  username             = local.gitea_username
  login_name           = local.gitea_username
  password             = data.vault_generic_secret.credentials.data[var.passwordkey]
  email                = "${local.gitea_username}@local.invalid"
  must_change_password = false
}
