variable "name" {
  type = string
}

data "cloudflare_zones" "domain" {
  name = data.vault_generic_secret.credentials.data["domain"]
}

locals {
  zone       = one(data.cloudflare_zones.domain.result)
  account_id = local.zone.account.id
  resource   = "com.cloudflare.edge.r2.bucket.${local.account_id}_default_${var.name}"
}

resource "cloudflare_r2_bucket" "uploads" {
  account_id    = local.account_id
  name          = var.name
  location      = "enam"
  storage_class = "Standard"
}

resource "cloudflare_r2_managed_domain" "uploads" {
  account_id  = local.account_id
  bucket_name = cloudflare_r2_bucket.uploads.name
  enabled     = true
}

data "cloudflare_api_token_permission_groups_list" "r2_write" {
  name = "Workers%20R2%20Storage%20Bucket%20Item%20Write"
}

resource "cloudflare_api_token" "uploads" {
  name = "${var.name}-read-write"

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = one(data.cloudflare_api_token_permission_groups_list.r2_write.result).id
    }]
    resources = jsonencode({
      (local.resource) = "*"
    })
  }]
}
