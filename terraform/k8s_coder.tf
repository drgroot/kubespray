resource "kubernetes_namespace" "coder" {
  metadata {
    name = "coder"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_secret" "coder" {
  metadata {
    name      = "coder-db-secret"
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  data = {
    CODER_PG_CONNECTION_URL = "postgres://${vault_generic_secret.database["postgres"].data.username}:${vault_generic_secret.database["postgres"].data.password}@${vault_generic_secret.database["postgres"].data.hostname}:${vault_generic_secret.database["postgres"].data.port}/coder?sslmode=disable"
  }
}

resource "kubernetes_service_account_v1" "coder" {
  metadata {
    name      = kubernetes_namespace.coder.metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  image_pull_secret {
    name = kubernetes_secret.docker_credentials["default"].metadata[0].name
  }
}

resource "kubernetes_role" "coder" {
  metadata {
    name      = kubernetes_service_account_v1.coder.metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  rule {
    api_groups = ["*"]
    resources = ["*"]
    verbs = ["*"]
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role" "coder" {
  metadata {
    name      = kubernetes_service_account_v1.coder.metadata[0].name
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
    name      = kubernetes_service_account_v1.coder.metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.coder.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_role_binding" "coder" {
  metadata {
    name      = "binding-coder-sa"
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.coder.metadata[0].name
    namespace = kubernetes_namespace.coder.metadata[0].name
  }

  role_ref {
    kind      = "Role"
    name      = kubernetes_role.coder.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}