resource "kubernetes_deployment_v1" "ddns" {
  metadata {
    name = "ddns"
    namespace = "default"
    labels = {
      app = "ddns"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "ddns"
      }
    }

    template {
      metadata {
        labels = {
          app = "ddns"
        }
      }

      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key = "onpremise"
                  operator = "Exists"
                  values = []
                }
              }  
            }  
          }  
        }

        container {
          image = "hotio/cloudflareddns"
          image_pull_policy = "Always"
          name  = "app"

          env {
            name = "CF_APIKEY"
            value = var.CLOUDFLARE_API_KEY
          }

          env {
            name = "CF_USER"
            value = var.CLOUDFLARE_EMAIL
          }

          env {
            name = "CF_ZONES"
            value = var.DOMAIN_NAME
          }

          env {
            name = "CF_HOSTS"
            value = "mordorhome.${var.DOMAIN_NAME}"
          }

          env {
            name = "CF_RECORDTYPES"
            value = "A" 
          }
        }
      }
    }
  }
}