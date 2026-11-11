variable "output" {
  type = string
}

resource "vault_generic_secret" "secrets" {
  path = var.output
  data_json = jsonencode({
    "database" : postgresql_database.application.name,
    "hostname" : data.vault_generic_secret.credentials.data["hostname"],
    "password" : local.db_password,
    "port" : 5432,
    "schema" : "public",
    "url" : format(
      "postgres://%s:%s@%s:%s/%s",
      postgresql_role.application.name,
      local.db_password,
      data.vault_generic_secret.credentials.data["hostname"],
      5432,
      postgresql_database.application.name,
    ),
    "username" : postgresql_role.application.name,
  })
}
