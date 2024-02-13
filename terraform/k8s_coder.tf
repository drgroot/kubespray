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
