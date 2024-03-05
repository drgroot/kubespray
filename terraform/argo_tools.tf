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

          secretStore:
            name: external-infra
            kind: SecretStore
          
          secrets: []

          tools:
            - name: gitlab
              image:
                name: ${local.versions.gitlab.name}
                tag: ${local.versions.gitlab.tag}
                suffix: "-ee.0"
              url: ${join(".", ["src", "yusufali.ca"])}
              ingress:
                annotations:
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
                  external-dns.alpha.kubernetes.io/target: "mordorhome.yusufali.ca"
                tls:
                  - hosts:
                      - "*.yusufali.ca"
                    secretName: wildcard-yusufali
              ports:
                - port: 8081
                - port: 22
              secrets: []
              resources: {}
              className: nfs-onpremise-dynamic
              volumes:
                - mountPath: /var/opt/gitlab
                  subPath: data
                - mountPath: /etc/gitlab
                  subPath: config
                - mountPath: /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub
                  subPath: license/.license_encryption_key.pub
                - mountPath: /opt/gitlab/embedded/service/gitlab-rails/.test_license_encryption_key.pub
                  subPath: license/.license_encryption_key.pub
              extraVolumeMounts:
                - name: dshm
                  mountPath: /dev/shm
              extraVolumes:
                - name: dshm
                  emptyDir:
                    medium: Memory
                    sizeLimit: "256Mi"
              affinity:
                nodeAffinity:
                  requiredDuringSchedulingIgnoredDuringExecution:
                    nodeSelectorTerms:
                      - matchExpressions:
                          - key: kubernetes.io/arch
                            operator: In
                            values:
                              - amd64
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
