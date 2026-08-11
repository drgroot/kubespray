variable "output" {
  type = string
}

resource "vault_generic_secret" "token" {
  path = var.output

  data_json = jsonencode({
    token = gitea_token.user.token
  })
}
