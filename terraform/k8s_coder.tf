resource "kubernetes_namespace" "coder" {
  metadata {
    name = "coder"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_namespace" "coder_workspace" {
  metadata {
    name = "coder-workspace"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_persistent_volume_claim" "coder" {
  metadata {
    name      = "workspace"
    namespace = kubernetes_namespace.coder.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "15Gi"
      }
    }
    storage_class_name = "nfs-onpremise-dynamic"
  }
}

resource "kubernetes_service_account_v1" "coder" {
  for_each = {
    (kubernetes_namespace.coder.metadata[0].name)           = kubernetes_namespace.coder.metadata[0].name,
    (kubernetes_namespace.coder_workspace.metadata[0].name) = kubernetes_namespace.coder.metadata[0].name
  }

  metadata {
    name      = each.key
    namespace = each.value
  }

  image_pull_secret {
    name = "docker-credentials"
  }
}

resource "kubernetes_role" "coder" {
  for_each = {
    (kubernetes_namespace.coder.metadata[0].name)           = kubernetes_namespace.coder.metadata[0].name,
    (kubernetes_namespace.coder_workspace.metadata[0].name) = kubernetes_namespace.coder_workspace.metadata[0].name
  }

  metadata {
    name      = "coder-role"
    namespace = each.value
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role" "coder" {
  metadata {
    name = "coder-cluster-role"
  }

  rule {
    api_groups = ["*"]
    resources  = ["persistentvolumes", "persistentvolumes/status", "nodes", "nodes/status", "customresourcedefinitions", "customresourcedefinitions/status"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "coder" {
  metadata {
    name = "cluster-binding-coder"
  }

  subject {
    kind      = "User"
    name      = kubernetes_namespace.coder.metadata[0].name
    api_group = ""
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.coder["coder"].metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.coder.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role_binding" "coder" {
  for_each = {
    (kubernetes_namespace.coder.metadata[0].name)           = kubernetes_namespace.coder.metadata[0].name,
    (kubernetes_namespace.coder_workspace.metadata[0].name) = kubernetes_namespace.coder_workspace.metadata[0].name
  }

  metadata {
    name      = "binding-coder-${each.key}-sa"
    namespace = each.key
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.coder[each.key].metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.coder[each.key].metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

locals {
  coder_services = {
    database = {
      cpu    = "250m"
      memory = "512Mi"
      port   = 5432
      image  = "postgres"
      env = {
        POSTGRES_USER     = "username"
        POSTGRES_PASSWORD = "password"
      }
      url_prefix = "postgresql://username:password@"
      url_suffix = ""
    }
    bus = {
      cpu    = "100m"
      memory = "50Mi"
      port   = 5672
      image  = "rabbitmq:3-management"
      env = {
        RABBITMQ_DEFAULT_VHOST = "test"
      }
      url_prefix = "amqp://"
      url_suffix = "/test"
    }
    cache = {
      cpu        = "100m"
      memory     = "250Mi"
      port       = 6379
      image      = "redis"
      env        = {}
      url_prefix = "redis://"
      url_suffix = ""
    }
  }
}

resource "kubernetes_deployment_v1" "coder_middleware" {
  for_each = local.coder_services

  metadata {
    name      = "coder-middleware-${each.key}"
    namespace = kubernetes_namespace.coder_workspace.metadata[0].name
    labels = {
      app = "coder-middleware-${each.key}"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        app = "coder-middleware-${each.key}"
      }
    }

    template {
      metadata {
        labels = {
          app = "coder-middleware-${each.key}"
        }
      }

      spec {
        container {
          name  = "app"
          image = each.value.image

          dynamic "env" {
            for_each = each.value.env

            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            requests = {
              cpu    = each.value.cpu
              memory = each.value.memory
            }
          }

          port {
            container_port = each.value.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "coder_middleware" {
  for_each = local.coder_services

  metadata {
    name      = kubernetes_deployment_v1.coder_middleware[each.key].metadata[0].name
    namespace = kubernetes_deployment_v1.coder_middleware[each.key].metadata[0].namespace
    labels    = kubernetes_deployment_v1.coder_middleware[each.key].spec[0].template[0].metadata[0].labels
  }

  spec {
    selector = kubernetes_deployment_v1.coder_middleware[each.key].spec[0].template[0].metadata[0].labels
    port {
      port        = local.coder_services[each.key].port
      target_port = local.coder_services[each.key].port
    }
  }
}

resource "kubernetes_secret" "coder_middleware" {
  for_each = local.coder_services

  metadata {
    name      = kubernetes_deployment_v1.coder_middleware[each.key].metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
    labels    = kubernetes_deployment_v1.coder_middleware[each.key].spec[0].template[0].metadata[0].labels
  }

  data = {
    "${upper(each.key)}_URL" = join(
      "",
      [
        each.value.url_prefix,
        kubernetes_service_v1.coder_middleware[each.key].metadata[0].name,
        ".",
        kubernetes_service_v1.coder_middleware[each.key].metadata[0].namespace,
        each.value.url_suffix
      ]
    )
  }
}
