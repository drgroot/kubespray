resource "kubernetes_namespace" "nfs" {
  metadata {
    name = "nfs"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "vault_generic_secret" "rclone" {
  path = "external-infra/RCLONE"

  data_json = jsonencode({
    "rclone.conf" = file(var.RCLONE_FILE)
  })
}

resource "kubernetes_secret" "rclone_secret" {
  metadata {
    name      = "rclone"
    namespace = kubernetes_namespace.nfs.metadata[0].name
  }

  data = vault_generic_secret.rclone.data
}

resource "kubernetes_manifest" "application_nfs" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "${kubernetes_manifest.project.manifest.metadata.name}-nfs"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      destination = {
        namespace = "argocd"
        server    = kubernetes_manifest.project.manifest.spec.destinations[0].server
      }

      project = kubernetes_manifest.project.manifest.metadata.name

      source = {
        path           = "charts/nfs"
        repoURL        = "https://github.com/drgroot/kubespray.git"
        targetRevision = "HEAD"

        helm = {
          values = <<-EOF
          spec:
            project: ${kubernetes_manifest.project.manifest.metadata.name}

          storage:
            - name: media
              hostname: ${var.STORAGE_HOSTNAME}
              mount_path: ${var.STORAGE_MEDIA}
              folders:
                - name: media
                  fixed: true
                - name: documents
                  fixed: true
            - name: onpremise
              hostname: ${var.STORAGE_HOSTNAME}
              mount_path: ${var.STORAGE_MOUNT}
              folders:
                - name: backups
                - name: dynamic
            - name: cloud
              hostname: 10.99.0.${local.storage_node.wg_index}
              mount_path: /var/lib/mounts
              folders:
                - name: downloads
                  fixed: true
          
          tasks:
            secrets:
              rclone: ${kubernetes_secret.rclone_secret.metadata[0].name}
            configs: []

            versions:
              nfs_provisioner: ${local.versions.nfs_provisioner}
          EOF
        }
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  field_manager {
    force_conflicts = true
  }
}
