variable "output" {
  type = string
}

resource "vault_generic_secret" "warehouse_secrets" {
  path = var.output

  data_json = jsonencode({
    accesskey      = b2_application_key.read_write.application_key_id
    blob-url       = data.b2_account_info.account.s3_api_url
    bucket         = b2_bucket.datalake.bucket_name
    region         = split(".", data.b2_account_info.account.s3_api_url)[1]
    secretkey      = b2_application_key.read_write.application_key
    read_accesskey = b2_application_key.read.application_key_id
    read_secretkey = b2_application_key.read.application_key
    rclone = <<-EOT
      [s3]
      type = alias
      remote = s3-main:${b2_bucket.datalake.bucket_name}

      [s3-main]
      type = s3
      provider = Other
      access_key_id = ${b2_application_key.read_write.application_key_id}
      secret_access_key = ${b2_application_key.read_write.application_key}
      endpoint = ${data.b2_account_info.account.s3_api_url}
      region = ${split(".", data.b2_account_info.account.s3_api_url)[1]}
    EOT
    warehouse      = "s3://${b2_bucket.datalake.bucket_name}"
  })
}
