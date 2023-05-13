resource "vault_generic_secret" "secrets" {
  path = "kubernetes/CLUSTER_INFORMATION" 
  data_json = jsonencode({
      CA_KEY_ALGORITHM   = "RSA"
      CA_PRIVATE_KEY_PEM = file(var.CA_KEY)
      CA_CERT_PEM        = file(var.CA_CERT)
      master_ip          = local.public_nodes[0].ip
      storage_node       = local.storage_node.name
      ADMINCONF          = file(var.ADMIN_CONF)

      ssl_tls_crt  = join("", [acme_certificate.certificate.certificate_pem, acme_certificate.certificate.issuer_pem])
      ssl_tls_key = acme_certificate.certificate.private_key_pem
      ssl_certificate_p12 = acme_certificate.certificate.certificate_p12
      ssl_certificate_p12_password = random_password.certificate_password.result
  })
}

resource "vault_generic_secret" "generic" {
  for_each = {
    DOCKER = merge(
      kubernetes_secret.docker_credentials["default"].data,
      {
        PUBLIC_REGISTRY_URL  = vault_generic_secret.docker.data.username
        PRIVATE_REGISTRY_URL = join(".",["registry",data.cloudflare_zones.domain.zones[0].name])
      }
    ),
    NPM = {
      username  = random_password.registryusername.result
      NPM_TOKEN = random_password.registrypassword.result
      NPM_HOST  = join(".",["npm",data.cloudflare_zones.domain.zones[0].name])
    }
  }

  path      = "kubernetes/${each.key}"
  data_json = jsonencode(each.value)
}

resource "vault_generic_secret" "email" {
  path = "external-infra/SMTP"
  data_json = jsonencode({
    MAIL_FROM_DOMAIN = var.MAIL_FROM_DOMAIN
    MAIL_FROM_EMAIL = join("@", [var.MAIL_FROM_USER, var.MAIL_FROM_DOMAIN])
    MAIL_FROM_USER   = var.MAIL_FROM_USER
    SMTP_EXPLICIT_TLS = var.SMTP_EXPLICIT_TLS
    SMTP_HOST         = var.SMTP_HOST
    SMTP_PASSWORD     = var.SMTP_PASSWORD
    SMTP_PORT         = var.SMTP_PORT
    SMTP_USERNAME     = var.SMTP_USERNAME
    SMTP_SSL          = var.SMTP_SSL
  })
}