variable "output" {
  type = string
}

resource "vault_generic_secret" "uploads" {
  path = var.output

  data_json = jsonencode({
    accountid = local.account_id
    accesskey = cloudflare_api_token.uploads.id
    secretkey = sha256(cloudflare_api_token.uploads.value)
    bucket    = cloudflare_r2_bucket.uploads.name
    blob-url  = "https://${cloudflare_r2_custom_domain.uploads.domain}"
    region    = "auto"
  })
}
