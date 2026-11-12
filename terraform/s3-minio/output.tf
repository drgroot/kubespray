variable "output" {
  type = string
}

# Forget the output on the previous Vault server without reading or deleting it.
# Keep the bucket and storage-provider credentials in their existing state.
removed {
  from = vault_generic_secret.warehouse_secrets
  lifecycle {
    destroy = false
  }
}

resource "vault_generic_secret" "connection" {
  path = var.output

  depends_on = [
    minio_iam_user_policy_attachment.datalake,
    minio_iam_user_policy_attachment.read,
  ]

  data_json = jsonencode({
    accesskey      = minio_iam_user.datalake.id
    blob-url       = data.vault_generic_secret.credentials.data["endpoint-url"]
    bucket         = minio_s3_bucket.datalake.bucket
    region         = data.vault_generic_secret.credentials.data["region"]
    secretkey      = minio_iam_user.datalake.secret
    read_accesskey = minio_iam_user.read.id
    read_secretkey = minio_iam_user.read.secret
    rclone         = <<-EOT
      [s3]
      type = alias
      remote = s3-main:${minio_s3_bucket.datalake.bucket}

      [s3-main]
      type = s3
      provider = Minio
      access_key_id = ${minio_iam_user.datalake.id}
      secret_access_key = ${minio_iam_user.datalake.secret}
      endpoint = ${data.vault_generic_secret.credentials.data["endpoint-url"]}
      region = ${data.vault_generic_secret.credentials.data["region"]}
      acl = private
    EOT
    warehouse      = "s3://${minio_s3_bucket.datalake.bucket}"
  })
}
