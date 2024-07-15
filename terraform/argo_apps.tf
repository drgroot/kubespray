data "vault_generic_secret" "tenants" {
  path = "external-infra/TENANTS" 
}

locals {
  tenants = nonsensitive(jsondecode(data.vault_generic_secret.tenants.data.tenants))
  tenant_map = merge(
    { for tenant in local.tenants : tenant.namespace => tenant },
    {
      default = { namespace = "default", flags = ["GIT", "DB_POSTGRES", "DOCKER_*", "RABBITMQ", "SMTP"] }
      certmanager = { namespace = "certmanager", flags = ["CLOUDFLARE"] }
      workspaces = { namespace = "workspaces", flags = ["DOCKER_*", "DB_POSTGRES", "RABBITMQ"] }
      nfs = { namespace = "nfs", flags = ["RCLONE", "DOCKER_PRIVATE"] }
      argocd = { namespace = "argocd", flags = ["GIT"] }
    }
  )
}

resource "kubernetes_manifest" "application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = kubernetes_manifest.project.manifest.metadata.name
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
        path           = "charts/app"
        repoURL        = "https://github.com/drgroot/kubespray.git"
        targetRevision = "HEAD"

        helm = {
          values = <<-EOF
          spec:
            project: ${kubernetes_manifest.project.manifest.metadata.name}
          
          secretStore:
            name: vault
            kind: SecretStore
            readWriteStore: readwrite-k8s

          stores:
            %{ for tenant in local.tenant_map }
            - name: kubernetes
              username: kubernetesreadonly${tenant.namespace}
              secretName: ${kubernetes_secret.vault_password_tenant[tenant.namespace].metadata[0].name}
              namespace: ${tenant.namespace}
              server: ${var.VAULT_ADDRESS}
              kind: SecretStore
            - name: vault
              username: kubernetesreadonly${tenant.namespace}
              secretName: ${kubernetes_secret.vault_password_tenant[tenant.namespace].metadata[0].name}
              namespace: ${tenant.namespace}
              server: ${var.VAULT_ADDRESS}
              kind: SecretStore
              path: external-infra
            %{ endfor }

            - name: readwrite-k8s
              username: ${var.VAULT_USERNAME}
              secretName: ${kubernetes_secret.vault_password_cluster.metadata[0].name}
              namespace: ${kubernetes_secret.vault_password_cluster.metadata[0].namespace}
              server: ${var.VAULT_ADDRESS}
              kind: SecretStore
              path: kubernetes

          externalsecrets:
            version: ${local.versions.externalsecrets}
            namespace: externalsecrets

          ingress:
            version: ${local.versions.ingress}
            namespace: ingress

          certmanager:
            secretstore: vault
            namespace: certmanager
            version: ${local.versions.certmanager}
            email: "ali@yusuf.email"
          
          externaldns:
            version: ${local.versions.externaldns}

          keda:
            version: ${local.versions.keda}
            namespace: keda

          prometheus:
            version: ${local.versions.prometheus}
            namespace: monitoring

          rabbitmq:
            secretstore: vault
            replicaCount: 1
            releaseName: rabbitmq
            version: ${local.versions.rabbitmq}
            namespace: default
            storageClass: nfs-thorin-ssd-raid0
            resources:
              requests:
                memory: 256Mi
                cpu: 50m

          redis:
            secretstore: vault
            releaseName: redis
            version: ${local.versions.redis}
            namespace: default
            resources:
              requests:
                memory: 256Mi
                cpu: 50m

          postgres:
            secretstore: vault
            releaseName: postgres
            replicaCount: 1
            version: ${local.versions.postgres}
            namespace: default
            storageClass: nfs-thorin-ssd-raid0
            backupStorageClass: nfs-thorin-backups
            resources:
              requests:
                memory: 4096Mi
                cpu: 512m

          gitea:
            secretstore: vault
            namespace: default
            version: ${local.versions.gitea}
            replicas: 1
            storageClass: nfs-thorin-dynamic

          coder:
            secretstore: vault
            namespace: workspaces
            pvcs:
              - name: workspace
                storageClassName: nfs-thorin-dynamic
              - name: datalake
                storageClassName: nfs-thorin-datalake
          
          registry:
            secretstore: vault
            namespace: default
            storageClass: nfs-thorin-dynamic

          ballista:
            namespace: ballista
            repo: yusufali
            maxExecutors: 2

          tenants:
            %{for tenant in local.tenants }
            - namespace: ${tenant.namespace}
              chart:
                url: ${tenant.repository.url}
                path: ${tenant.repository.path}
              flags:
                %{ for flag in tenant.flags }
                - ${flag}
                %{ endfor }
            %{ endfor }
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
