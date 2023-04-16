resource "random_string" "database_username" {
  length = 16
  special = false
}

resource "random_password" "database_password" {
  length = 16
  special = false
}

locals {
  databases = {
    postgres = {
      override_username = true
      volume_mount = "/var/lib/postgresql/data"
      username = "POSTGRES_USER"
      password = "POSTGRES_PASSWORD"
      port = 5432
      live_check = ["/bin/bash","-c", "psql -U $POSTGRES_USER -c 'SELECT 1'"]
    }
    mysql = {
      volume_mount = "/var/lib/mysql"
      username = "root"
      override_username = false
      password = "MYSQL_ROOT_PASSWORD"
      port = 3306
      live_check = ["/bin/bash","-c", "mysql -u root -p${random_password.database_password.result} -e 'SELECT 1'"]
    }
    mariadb = {
      volume_mount = "/var/lib/mysql"
      username = "root"
      override_username = false
      password = "MYSQL_ROOT_PASSWORD"
      port = 3306
      live_check = ["/bin/bash","-c", "mysql -u root -p${random_password.database_password.result} -e 'SELECT 1'"]
    }
  }
}

resource "kubernetes_persistent_volume_claim" "database_pvc" {
  for_each = local.versions.databases

  metadata {
    name = "database-${each.key}-pvc"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "15Gi"
      }
    }
  }
}

resource "kubernetes_deployment_v1" "database" {
  for_each = local.versions.databases

  metadata {
    name = "database-${each.key}"
    labels = {
      app = "database-${each.key}"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "database-${each.key}"
      }
    }

    template {
      metadata {
        labels = {
          app = "database-${each.key}"
        }
      }

      spec {
        container {
          name = each.key
          image = "${each.key}:${each.value}"

          volume_mount {
            name = "data"
            mount_path = local.databases[each.key].volume_mount
            sub_path = "data"
          }

          resources {
            requests = {
              cpu = "512m"
              memory = "1024Mi"
            }
          }

          env {
            name = local.databases[each.key].override_username ? local.databases[each.key].username : "MYasdSQL_PsadWD"
            value = random_string.database_username.result
          }

          env {
            name = local.databases[each.key].password
            value = random_password.database_password.result
          }

          port {
            container_port = local.databases[each.key].port
          }

          readiness_probe {
            exec {
              command =  local.databases[each.key].live_check
            }
            initial_delay_seconds = 45
            timeout_seconds = 5
          }

          liveness_probe {
            exec {
              command = local.databases[each.key].live_check
            }
            initial_delay_seconds = 45
            timeout_seconds = 5
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.database_pvc[each.key].metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "database" {
  for_each = local.versions.databases

  metadata {
    name = kubernetes_deployment_v1.database[each.key].metadata[0].name
  }

  spec {
    selector = kubernetes_deployment_v1.database[each.key].spec[0].template[0].metadata[0].labels
    port {
      port = local.databases[each.key].port
      target_port = local.databases[each.key].port
    }
  }
}

resource "vault_generic_secret" "database" {
  for_each = local.versions.databases

  path = "kubernetes/DATABASE_${upper(each.key)}"
  data_json = jsonencode({
    hostname = "${kubernetes_service_v1.database[each.key].metadata[0].name}.default.svc.cluster.local"
    password = random_password.database_password.result
    port = kubernetes_service_v1.database[each.key].spec[0].port[0].port
    username = local.databases[each.key].override_username ? random_string.database_username.result : local.databases[each.key].username
  })
}