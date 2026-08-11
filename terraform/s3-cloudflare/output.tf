variable "output" {
  type = string
}

resource "vault_generic_secret" "warehouse_secrets" {
  path = var.output

  data_json = jsonencode({
    accesskey      = cloudflare_api_token.token.id
    blob-url       = "https://${var.account_id}.r2.cloudflarestorage.com"
    bucket         = cloudflare_r2_bucket.lake.name
    region         = cloudflare_r2_bucket.lake.location
    secretkey      = sha256(cloudflare_api_token.token.value)
    read_accesskey = cloudflare_account_token.read.id
    read_secretkey = sha256(cloudflare_account_token.read.value)
    rclone = <<-EOT
      [s3]
      type = alias
      remote = s3-main:${cloudflare_r2_bucket.lake.name}

      [s3-main]
      type = s3
      provider = Cloudflare
      access_key_id = ${cloudflare_api_token.token.id}
      secret_access_key = ${sha256(cloudflare_api_token.token.value)}
      endpoint = https://${var.account_id}.r2.cloudflarestorage.com
      region = ${cloudflare_r2_bucket.lake.location}
      acl = private
      no_check_bucket = true
    EOT
    warehouse = "s3://${cloudflare_r2_bucket.lake.name}"
  })
}
