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
            name: ${local.cluster_secret_store_name}
            kind: ClusterSecretStore
          
          secrets:
            docker-credentials:
              namespace: ${kubernetes_namespace.coder.metadata[0].name}
              template:
                .dockerconfigjson: |
                  {
                    "auths": {
                      "https://registry.yusufali.ca": {
                        "auth": {{ b64enc (print .USERNAME ":" .PASSWORD ) | quote }}
                      }
                    }
                  }
              data:
                - name: USERNAME
                  key: DOCKER
                  property: PRIVATE_USERNAME
                - name: PASSWORD
                  key: DOCKER
                  property: PRIVATE_PASSWORD
            docker-credentials:
              namespace: ${kubernetes_namespace.coder_workspace.metadata[0].name}
              type: kubernetes.io/dockerconfigjson
              template:
                .dockerconfigjson: |
                  {
                    "auths": {
                      "https://registry.yusufali.ca": {
                        "auth": {{ b64enc (print .USERNAME ":" .PASSWORD ) | quote }}
                      }
                    }
                  }
              data:
                - name: USERNAME
                  key: DOCKER
                  property: PRIVATE_USERNAME
                - name: PASSWORD
                  key: DOCKER
                  property: PRIVATE_PASSWORD
            postgres-credentials:
              namespace: ${kubernetes_namespace.coder.metadata[0].name}
              data:
                - key: DB_POSTGRES
                  property: USERNAME
                - key: DB_POSTGRES
                  property: PASSWORD
            registry-credentials:
              template:
                htpasswd: |-
                  {{ htpasswd .PRIVATE_USERNAME .PRIVATE_PASSWORD }}
              data:
                - key: DOCKER
                  property: PRIVATE_USERNAME
                - key: DOCKER
                  property: PRIVATE_PASSWORD

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
            - name: coder
              image:
                name: ${local.versions.coder.name}
                tag: ${local.versions.coder.tag}
              url: "${join(".", ["coder", "yusufali.ca"])}"
              extraIngress: 
                - host: "${join(".", ["*.coder", "yusufali.ca"])}"
                  paths:
                    - path: /
                      pathType: Prefix
              ingress:
                annotations:
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
                  external-dns.alpha.kubernetes.io/target: "mordorhome.yusufali.ca"
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
                - name: POSTGRES_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres-credentials
                      key: PASSWORD
                - name: POSTGRES_USERNAME
                  valueFrom:
                    secretKeyRef:
                      name: postgres-credentials
                      key: USERNAME
                - name: CODER_PG_CONNECTION_URL
                  value: "postgres://$(POSTGRES_USERNAME):$(POSTGRES_PASSWORD)@${kubernetes_service_v1.database["postgres"].metadata[0].name}.${kubernetes_service_v1.database["postgres"].metadata[0].namespace}.svc.cluster.local/coder?sslmode=disable"
              secrets: []
              ports:
                - port: 7080
              resources: {}
              namespace: ${kubernetes_namespace.coder.metadata[0].name}
              serviceAccount: ${kubernetes_service_account_v1.coder["coder"].metadata[0].name}
            - name: registry
              image:
                name: ${local.versions.registry.name}
                tag: ${local.versions.registry.tag}
              url: ${join(".", ["registry", "yusufali.ca"])}
              ingress:
                annotations:
                  nginx.ingress.kubernetes.io/client-body-buffer-size: 5000m
                  nginx.ingress.kubernetes.io/proxy-body-size: 5000m
                  kubernetes.io/ingress.class: nginx
                  cert-manager.io/cluster-issuer: letsencrypt-prod
                  nginx.ingress.kubernetes.io/ssl-redirect: "true"
                  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
                  external-dns.alpha.kubernetes.io/target: "mordorhome.yusufali.ca"
                tls:
                  - hosts:
                      - "*.yusufali.ca"
                    secretName: wildcard-yusufali
              secrets: []
              ports:
                - port: 5000
              className: nfs-onpremise-dynamic
              securityContext:
                runAsGroup: 1000
                runAsUser: 1000
              resources:
                requests:
                  cpu: 100m
                  memory: 200Mi
              volumes:
                - mountPath: /var/lib/registry
              env:
                - name: REGISTRY_AUTH
                  value: "htpasswd"
                - name: REGISTRY_AUTH_HTPASSWD_REALM
                  value: "Registry Realm"
                - name: REGISTRY_AUTH_HTPASSWD_PATH
                  value: "/auth/htpasswd"
                - name: REGISTRY_STORAGE_MAINTENANCE
                  value: |
                    uploadpurging:
                      enabled: true
                      age: 48h
                      interval: 24h
                      dryrun: false
                    readonly:
                      enabled: false
                    delete:
                      enabled: true
              extraVolumes:
                - name: htpasswd
                  secret:
                    secretName: registry-credentials
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
