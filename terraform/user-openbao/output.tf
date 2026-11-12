resource "vault_generic_secret" "output" {
  provider = vault.admin
  path     = var.output

  data_json = jsonencode({
    username     = local.username
    password     = local.password
    token        = vault_token.user.client_token
    "vault-addr" = var.openbao_addr
  })

  depends_on = [vault_generic_endpoint.userpass_user]
}
