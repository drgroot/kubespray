data "vault_generic_secret" "tenants" {
  path = "kubernetes/TENANTS" 
}

locals {
  tenants = jsondecode(data.vault_generic_secret.tenants.data.tenants)
}

resource "random_password" "username" {
  count = length(local.tenants)
  
  length  = 30
  special = false
}

resource "random_password" "password" {
  count = length(local.tenants)

  length  = 30
  special = false
}

resource "vault_generic_secret" "authentication" {
  count = length(local.tenants)
  
  path = "kubernetes/${local.tenants[count.index].namespace}-vault-authenticator"
  data_json = jsonencode({
      username = random_password.username[count.index].result
      password = random_password.password[count.index].result
  })
}

resource "drone_secret" "vault_username" {
  count = length(local.tenants)

  repository = local.tenants[count.index].repository
  name       = "VAULT_USERNAME"
  value      = random_password.username[count.index].result
  allow_on_pull_request = true
}

resource "drone_secret" "vault_password" {
  count = length(local.tenants)

  repository = local.tenants[count.index].repository
  name       = "VAULT_PASSWORD"
  value      = random_password.password[count.index].result
  allow_on_pull_request = true
}