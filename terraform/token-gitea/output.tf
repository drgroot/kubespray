variable "output" {
  type = string
}

removed {
  from = vault_generic_secret.token
  lifecycle {
    destroy = false
  }
}

resource "vault_generic_secret" "connection" {
  path = var.output

  data_json = jsonencode({
    username = var.name
    password = data.vault_generic_secret.credentials.data[var.passwordkey]
    token    = gitea_token.user.token
  })
}
