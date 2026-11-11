variable "input" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.input
}

provider "postgresql" {
  superuser = false
  host      = data.vault_generic_secret.credentials.data["hostname"]
  port      = 5432
  database  = data.vault_generic_secret.credentials.data["database"]
  username  = data.vault_generic_secret.credentials.data["username"]
  password  = data.vault_generic_secret.credentials.data["password"]
  sslmode   = "disable"
}
