resource "random_string" "database_username" {
  length = 16
  special = false
}

resource "random_password" "database_password" {
  length = 16
  special = false
}

locals {
  backup_location = "/backup/backup.sql"
  databases = {
    postgres = {
      override_username = true
      volume_mount = "/var/lib/postgresql/data"
      username = "POSTGRES_USER"
      password = "POSTGRES_PASSWORD"
      port = 5432
      live_check = ["/bin/bash","-c", "psql -U $POSTGRES_USER -c 'SELECT 1'"]
      backup = ["/bin/bash", "-c", "export PGPASSWORD=${random_password.database_password.result}; pg_dumpall -U ${random_string.database_username.result} -h $DATABASE_HOST -p $DATABASE_PORT --clean --file=${local.backup_location}"]
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
      backup = ["/bin/bash","-c", "mysqldump -h $DATABASE_HOST -P $DATABASE_PORT -u root -p${random_password.database_password.result} --all-databases --skip-lock-tables > ${local.backup_location}"]
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
    storage_class_name = "nfs-onpremise-dynamic"
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
            sub_path = each.key
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

resource "kubernetes_persistent_volume_claim" "database_backup_pvc" {
  for_each = local.versions.databases

  metadata {
    name = "database-backup-${each.key}-pvc"
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "15Gi"
      }
    }
    storage_class_name = "nfs-onpremise-backups"
  }
}

resource "kubernetes_cron_job_v1" "database_backup" {
  for_each = local.versions.databases

  metadata {
    name = "database-backup-${each.key}"
  }

  spec {
    concurrency_policy = "Forbid"
    failed_jobs_history_limit = 1
    schedule = "1 0 * * *"
    successful_jobs_history_limit = 0

    job_template {
      metadata {
        name = "database-backup-${each.key}"
      }

      spec {
        backoff_limit = 1
        template {
          metadata {
            name = "database-backup-${each.key}"
          }

          spec {

            security_context {
              run_as_user = 1000
              run_as_group = 1000
            }

            container {
              name = each.key
              image = "${each.key}:${each.value}"
              command = local.databases[each.key].backup

              volume_mount {
                name = "backup"
                mount_path = dirname(local.backup_location)
              }

              env {
                name = "DATABASE_HOST"
                value = "${kubernetes_service_v1.database[each.key].metadata[0].name}.default.svc.cluster.local"
              }

              env {
                name = "DATABASE_PORT"
                value = tostring(kubernetes_service_v1.database[each.key].spec[0].port[0].port)
              }
            }

            volume {
              name = "backup"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.database_backup_pvc[each.key].metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}