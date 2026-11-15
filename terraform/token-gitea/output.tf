variable "output" {
  type = string
}

resource "vault_generic_secret" "connection" {
  path = var.output

  data_json = jsonencode({
    username = local.gitea_username
    password = data.vault_generic_secret.credentials.data[var.passwordkey]
    token    = gitea_token.user.token
  })
}
