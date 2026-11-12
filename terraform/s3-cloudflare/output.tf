variable "output" {
  type = string
}

# Forget the output on the previous Vault server without reading or deleting it.
# Keep the bucket and storage-provider credentials in their existing state.
removed {
  from = vault_generic_secret.uploads
  lifecycle {
    destroy = false
  }
}

resource "vault_generic_secret" "connection" {
  path = var.output

  data_json = jsonencode({
    accountid = local.account_id
    accesskey = cloudflare_api_token.uploads.id
    secretkey = sha256(cloudflare_api_token.uploads.value)
    bucket    = cloudflare_r2_bucket.uploads.name
    blob-url  = "https://${cloudflare_r2_managed_domain.uploads.domain}"
    region    = "auto"
  })
}
