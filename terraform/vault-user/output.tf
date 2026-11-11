resource "vault_generic_secret" "output" {
  path = var.output

  data_json = jsonencode({
    username     = local.username
    password     = local.password
    token        = vault_token.user.client_token
    "vault-addr" = var.vault_addr
  })

  depends_on = [vault_generic_endpoint.userpass_user]
}
