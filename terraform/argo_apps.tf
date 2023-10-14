locals {
  cluster_secret_store_name = "cluster-readonly-secretstore"
}

resource "kubernetes_manifest" "project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "bootstrap"
      namespace = "argocd"
      labels = {
        "app.kubernetes.io/part-of" = "argocd"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      sourceRepos = ["*"]

      destinations = [{
        namespace = "*"
        server    = "https://kubernetes.default.svc"
      }]

      syncWindows = [
        {
          kind         = "allow"
          schedule     = "10 */4 * * *"
          duration     = "1h"
          applications = ["*"]
          clusters     = ["*"]
          namespaces   = ["*"]
          timeZone     = "America/Toronto"
          manualSync   = true
        }
      ]

      clusterResourceWhitelist = [{
        group = "*"
        kind  = "*"
      }]

      namespaceResourceWhitelist = [{
        group = "*"
        kind  = "*"
      }]
    }
  }
  field_manager {
    force_conflicts = true
  }
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
            namespace: networking

          certmanager:
            namespace: certmanager
            version: ${local.versions.certmanager}
            email: "ali@yusuf.email"
          
          externaldns:
            version: ${local.versions.externaldns}

          keda:
            version: ${local.versions.keda}
            namespace: keda

          externalsecrets:
            version: ${local.versions.externalsecrets}
            namespace: externalsecrets

          gitlabrunner:
            version: ${local.versions.gitlabrunner}
            namespace: gitlab

          prometheus:
            version: ${local.versions.prometheus}
            namespace: monitoring

          tenants:
            %{for tenant in nonsensitive(jsondecode(data.vault_generic_secret.tenants.data.tenants)) }
            - namespace: ${tenant.namespace}
              docker:
                ${contains(tenant.flags, "docker") ? "- PUBLIC_" : ""}
                ${contains(tenant.flags, "docker:private") ? "- PRIVATE_" : ""}
              externalinfra:
                ${contains(tenant.flags, "smtp") ? "- SMTP" : ""}
                ${contains(tenant.flags, "rclone") ? "- RCLONE" : ""}
              databases:
                %{ for key in nonsensitive(keys(local.database_access_credentials)) }
                ${ local.database_access_credentials[key].namespace == tenant.namespace ? "- ${replace(vault_generic_secret.database_credential[key].path,"kubernetes/","")}" : ""}
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
