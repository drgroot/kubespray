variable "credentialpath" {
  type = string
}

variable "passwordkey" {
  type = string
}

variable "name" {
  type = string
}

data "vault_generic_secret" "db_user_credentials" {
  path = var.credentialpath
}

locals {
  database_name    = "db_${var.name}"
  db_username      = var.name
  db_password      = data.vault_generic_secret.db_user_credentials.data[var.passwordkey]
}

resource "postgresql_role" "application" {
  name     = local.db_username
  login    = true
  password = local.db_password
}

resource "postgresql_database" "application" {
  name                   = local.database_name
  owner                  = postgresql_role.application.name
  alter_object_ownership = true
}

resource "postgresql_schema" "public" {
  database      = postgresql_database.application.name
  name          = "public"
  owner         = postgresql_role.application.name
  if_not_exists = true

  policy {
    role   = postgresql_role.application.name
    usage  = true
    create = true
  }
}

resource "postgresql_grant" "database" {
  database    = postgresql_database.application.name
  role        = postgresql_role.application.name
  object_type = "database"
  privileges  = ["CONNECT", "CREATE", "TEMPORARY"]
}

resource "postgresql_grant" "schema" {
  database    = postgresql_database.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

resource "postgresql_grant" "tables" {
  database    = postgresql_database.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

resource "postgresql_grant" "sequences" {
  database    = postgresql_database.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}

resource "postgresql_grant" "routines" {
  database    = postgresql_database.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "routine"
  privileges  = ["EXECUTE"]
}

resource "postgresql_default_privileges" "tables" {
  database    = postgresql_database.application.name
  owner       = postgresql_role.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "table"
  privileges  = ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER"]
}

resource "postgresql_default_privileges" "sequences" {
  database    = postgresql_database.application.name
  owner       = postgresql_role.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT", "UPDATE"]
}

resource "postgresql_default_privileges" "routines" {
  database    = postgresql_database.application.name
  owner       = postgresql_role.application.name
  role        = postgresql_role.application.name
  schema      = postgresql_schema.public.name
  object_type = "routine"
  privileges  = ["EXECUTE"]
}
