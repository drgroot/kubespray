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
            - name: onpremise
              hostname: 192.168.1.4
              folders:
                - name: backups
                  mountPath: /volume2/containerData
                  subPath: backups
                - name: dynamic
                  mountPath: /volume2/containerData
                  subPath: dynamic
                - name: media
                  mountPath: /volume2/media
                  fixed: true
                  backup:
                    enabled: true
                    schedule: "0 0 * * *"
                    subPath: photos/upload
            - name: thorin
              hostname: 192.168.1.3
              folders:
                - name: documents
                  fixed: true
                  backup:
                    enabled: true
                    schedule: "0 */4 * * *"
                - name: media
                  fixed: true
                - name: downloads
                  fixed: true
                - name: ssd-raid0
                - name: datalake
                  fixed: true
                  backup:
                    enabled: true
                    schedule: "0 0 * * *"
          
          secretStore:
            name: vault
            kind: SecretStore
          
          tasks:
            - name: backup
              image: registry.yusufali.ca/containers/backup:latest
              imageSecret: cluster-docker-private
              secrets:
                - rclone
              pvc: nfs-onpremise-dynamic

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
