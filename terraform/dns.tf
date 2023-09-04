data "cloudflare_zones" "domain" {
  filter {
    name = var.DOMAIN_NAME
  }
}

data "vault_generic_secret" "secrets" {
  path = "kubernetes/TENANTS"
}

locals {
  namespace_cnames = flatten([
    for x in jsondecode(data.vault_generic_secret.secrets.data.tenants) : concat([
      contains(x.flags, "dns") ? ["*.${x.namespace}", x.namespace] : [],
    ])
  ])
  all_cnames = concat(
    [
      "*",
      "coder",
      "*.coder",
      # data.cloudflare_zones.domain.zones[0].name,
    ],
    local.namespace_cnames
  )
}

resource "cloudflare_record" "mail" {
  for_each = {
    "aspmx.l.google.com" : "1",
    "alt1.aspmx.l.google.com" : "5",
    "alt2.aspmx.l.google.com" : "5",
    "alt3.aspmx.l.google.com" : "10",
    "alt4.aspmx.l.google.com" : "10",
  }

  zone_id  = data.cloudflare_zones.domain.zones[0].id
  name     = "@"
  value    = each.key
  type     = "MX"
  priority = each.value
}

resource "cloudflare_record" "subdomains" {
  count = length(local.all_cnames)

  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = local.all_cnames[count.index]
  value   = "mordorhome.${data.cloudflare_zones.domain.zones[0].name}"
  type    = "CNAME"
  proxied = false
  ttl     = 1
}

resource "kubernetes_secret" "certmanager" {
  metadata {
    name      = "cert-manager-cloudflarekey"
    namespace = kubernetes_namespace.certmanager.metadata[0].name
  }

  data = {
    CLOUDFLARE_API_KEY = var.CLOUDFLARE_API_KEY
  }
}

resource "kubernetes_secret" "cloudflarekey" {
  metadata {
    name      = "cloudflarekey"
    namespace = "default"
  }

  data = {
    CF_API_KEY = var.CLOUDFLARE_API_KEY
  }
}

resource "kubernetes_namespace" "networking" {
  metadata {
    name = "networking"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

resource "kubernetes_namespace" "certmanager" {
  metadata {
    name = "cert-manager"
  }

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}
