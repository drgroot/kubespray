variable "name" {
  type = string
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

resource "gitea_token" "user" {
  name   = "${local.gitea_username}-opentofu"
  scopes = ["all"]

  depends_on = [gitea_user.user]
}
