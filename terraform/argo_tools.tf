resource "kubernetes_manifest" "application_tools" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "${kubernetes_manifest.project.manifest.metadata.name}-tools"
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
        path           = "charts/tools"
        repoURL        = "https://github.com/drgroot/kubespray.git"
        targetRevision = "HEAD"

        helm = {
          values = <<-EOF
          spec:
            project: ${kubernetes_manifest.project.manifest.metadata.name}

          tools:
            - name: drone
              image:
                name: ${local.versions.drone.name}
                semvar: ${local.versions.drone.semvar}
                tag: ${local.versions.drone.tag}
              url: ${join(".",["drone",data.cloudflare_zones.domain.zones[0].name])}
              ingress:
                annotations:
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                tls:
                  - hosts:
                      - "*.yusufali.ca"
                    secretName: wildcard-yusufali
              secrets: 
                - ${kubernetes_secret.drone.metadata[0].name}
              resources: {}
              ports:
                - port: 80
            - name: drone-runner
              namespace: ${kubernetes_namespace.drone_runner.metadata[0].name}
              serviceAccount: ${kubernetes_service_account_v1.drone_runner.metadata[0].name}
              image:
                name: "drone/drone-runner-kube"
                tag: "latest"
                semvar: "latest"
              ports:
                - port: 3000
              resources: {}
              secrets:
                - drone-runner
            - name: gitea
              image:
                name: ${local.versions.gitea.name}
                semvar: ${local.versions.gitea.semvar}
                tag: ${local.versions.gitea.tag}
                suffix: "-rootless"
              url: ${join(".",["git",data.cloudflare_zones.domain.zones[0].name])}
              ingress:
                annotations:
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
                tls:
                  - hosts:
                      - "*.yusufali.ca"
                    secretName: wildcard-yusufali
              secrets:
                - ${kubernetes_secret.gitea.metadata[0].name}
              ports:
                - port: 3000
                - port: 2222
              securityContext:
                runAsGroup: 1000
                runAsUser: 1000
              resources: {}
              className: nfs-onpremise-dynamic
              volumes:
                - mountPath: /var/lib/gitea
                  subPath: data
                - mountPath: /etc/gitea
                  subPath: config
            - name: coder
              image:
                name: "ghcr.io/coder/coder"
                semvar: "~v2.x.x"
                tag: "v2.1.4"
              url: "${join(".",["coder",data.cloudflare_zones.domain.zones[0].name])}"
              extraIngress: 
                - host: "${join(".",["*.coder",data.cloudflare_zones.domain.zones[0].name])}"
                  paths:
                    - path: /
                      pathType: Prefix
              ingress:
                annotations:
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
                tls:
                  - hosts:
                      - "coder.yusufali.ca"
                      - "*.coder.yusufali.ca"
                    secretName: coder-yusufali
              env:
                - name: CODER_TAILSCALE
                  value: "true"
                - name: CODER_ACCESS_URL
                  value: "https://coder.yusufali.ca"
                - name: CODER_ADDRESS
                  value: "0.0.0.0:7080"
              secrets:
                - ${kubernetes_secret.coder.metadata[0].name}
              ports:
                - port: 7080
              resources: {}
              namespace: ${kubernetes_namespace.coder.metadata[0].name}
              serviceAccountName: ${kubernetes_service_account_v1.coder.metadata[0].name}
            - name: registry
              image:
                name: registry
                semvar: ~2
                tag: 2
              url: ${join(".",["registry",data.cloudflare_zones.domain.zones[0].name])}
              ingress:
                annotations:
                  nginx.ingress.kubernetes.io/client-body-buffer-size: 5000m
                  nginx.ingress.kubernetes.io/proxy-body-size: 5000m
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
                tls:
                  - hosts:
                      - "*.yusufali.ca"
                    secretName: wildcard-yusufali
              secrets:
                - ${kubernetes_secret.registry.metadata[0].name}
              ports:
                - port: 5000
              className: nfs-onpremise-dynamic
              securityContext:
                runAsGroup: 1000
                runAsUser: 1000
              resources: {}
              volumes:
                - mountPath: /var/lib/registry
              extraVolumes:
                - name: htpasswd
                  secret:
                    secretName: ${kubernetes_secret.registryAuth.metadata[0].name}
              extraVolumeMounts:
                - name: htpasswd
                  mountPath: /auth
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
