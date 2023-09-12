data "vault_generic_secret" "tenants" {
  path = "kubernetes/TENANTS" 
}

locals {
  tenants = jsondecode(data.vault_generic_secret.tenants.data.tenants)
  database_access_credentials = {
    for x in flatten(
      flatten([
        for db_type in keys(local.databases): [
          for tenant in jsondecode(data.vault_generic_secret.tenants.data.tenants): [
            for flag in tenant.flags: {
              key = join("-",[db_type, tenant.namespace, split(":", flag)[1]])
              type = db_type
              namespace = tenant.namespace
              databaseName = split(":", flag)[1]

              username = split(":", flag)[1]
              password = split(":", flag)[1]

              host = "${kubernetes_service_v1.database[db_type].metadata[0].name}.${kubernetes_service_v1.database[db_type].metadata[0].namespace}.svc.cluster.local"
              port = kubernetes_service_v1.database[db_type].spec[0].port[0].port
            } if contains(split(":", flag), db_type)
          ]
        ]
      ])
    ): x.key => x
  }
}

# make database credentials and store in the vault
resource "vault_generic_secret" "database_credential" {
  for_each = { for x in nonsensitive(keys(local.database_access_credentials)): x => local.database_access_credentials[x] }

  path = "kubernetes/DB_${each.key}"
  data_json = jsonencode({
    host = each.value.host
    password = each.value.password
    port = each.value.port
    username = each.value.username
    database  = each.value.databaseName
  })
}