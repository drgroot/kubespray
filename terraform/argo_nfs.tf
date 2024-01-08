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
            - name: media-thorin
              hostname: ${var.STORAGE_THORIN_HOSTNAME}
              mount_path: ${var.STORAGE_THORIN_MOUNT}
              folders:
                - name: media
                  fixed: true
            - name: media
              hostname: ${var.STORAGE_HOSTNAME}
              mount_path: ${var.STORAGE_MEDIA}
              folders:
                - name: media
                  fixed: true
                  upload: true
                - name: documents
                  fixed: true
            - name: onpremise
              hostname: ${var.STORAGE_HOSTNAME}
              mount_path: ${var.STORAGE_MOUNT}
              folders:
                - name: backups
                - name: dynamic
          
          secretStore:
            name: ${local.cluster_secret_store_name}
          
          tasks:
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
