data "vault_generic_secret" "tenants" {
  path = "kubernetes/TENANTS" 
}

locals {
  cluster_secret_store_name = "cluster-readonly-secretstore"
  tenants = jsondecode(data.vault_generic_secret.tenants.data.tenants)
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
          
          externalsecrets:
            version: ${local.versions.externalsecrets}
            namespace: externalsecrets
            stores:
              vault:
                server: ${var.VAULT_ADDRESS}
                secretStore:
                  name: ${local.cluster_secret_store_name}
                  username: kubernetesreadonly
                  secretRef:
                    name: ${kubernetes_secret.vault_password.metadata[0].name}
                    namespace: ${kubernetes_secret.vault_password.metadata[0].namespace}
                    key: ${keys(kubernetes_secret.vault_password.data)[0]} 

          ingress:
            version: ${local.versions.ingress}
            namespace: ingress

          certmanager:
            namespace: certmanager
            version: ${local.versions.certmanager}
            email: "ali@yusuf.email"
          
          externaldns:
            version: ${local.versions.externaldns}

          keda:
            version: ${local.versions.keda}
            namespace: keda

          rabbitmq:
            releaseName: rabbitmq
            version: ${local.versions.rabbitmq}
            namespace: default
            storageClass: nfs-thorin-ssd-raid0
            resources:
              requests:
                memory: 256Mi
                cpu: 50m

          redis:
            releaseName: rabbitmq
            version: ${local.versions.redis}
            namespace: default
            resources:
              requests:
                memory: 256Mi
                cpu: 50m

          postgres:
            releaseName: postgres
            version: ${local.versions.postgres}
            namespace: default
            storageClass: nfs-thorin-ssd-raid0
            backupStorageClass: nfs-onpremise-backups
            resources:
              requests:
                memory: 8192Mi
                cpu: 1000m

          gitea:
            namespace: default
            version: ${local.versions.gitea}
            replicas: 1
            storageClass: nfs-onpremise-dynamic

          coder:
            namespace: default
            workspaces:
              namespace: workspaces
            pvcs:
              - name: workspace
                storageClassName: nfs-onpremise-dynamic
              - name: datalake
                storageClassName: nfs-thorin-datalake

          tenants:
            %{for tenant in nonsensitive(jsondecode(data.vault_generic_secret.tenants.data.tenants)) }
            - namespace: ${tenant.namespace}
              docker:
                ${contains(tenant.flags, "docker") ? "- PUBLIC_" : ""}
                ${contains(tenant.flags, "docker:private") ? "- PRIVATE_" : ""}
              externalinfra:
                ${contains(tenant.flags, "smtp") ? "- SMTP" : ""}
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

data "kubernetes_secret" "rabbitmq" {
  metadata {
    name      = "rabbitmq"
    namespace = "default"
  }
}

resource "vault_generic_secret" "rabbitmq" {
  path = "kubernetes/rabbitmq-secrets"
  data_json = jsonencode({
    username = "user"
    password = data.kubernetes_secret.rabbitmq.data["rabbitmq-password"]
    host = "rabbitmq-headless.default.svc.cluster.local"
    url = "amqp://user:${data.kubernetes_secret.rabbitmq.data["rabbitmq-password"]}@rabbitmq-headless.default.svc.cluster.local"
  })
}

resource "vault_generic_secret" "redis" {
  path = "kubernetes/redis-secrets"
  data_json = jsonencode({
    host = "redis-headless.default.svc.cluster.local"
    url = "redis://redis-headless.default.svc.cluster.local"
  })
}

resource "vault_generic_secret" "postgres" {
  path = "kubernetes/postgres-secrets"
  data_json = jsonencode({
    host = "postgres-pgpool.default.svc.cluster.local"
  })
}
