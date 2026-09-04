variable "output" {
  type = string
}

resource "vault_generic_secret" "warehouse_secrets" {
  path = var.output

  depends_on = [
    ovh_cloud_project_user_s3_policy.read_write,
    ovh_cloud_project_user_s3_policy.read,
  ]

  data_json = jsonencode({
    accesskey      = ovh_cloud_project_user_s3_credential.read_write.access_key_id
    blob-url       = "https://s3.${lower(var.region)}.io.cloud.ovh.net"
    bucket         = ovh_cloud_project_storage.datalake.name
    region         = lower(var.region)
    secretkey      = ovh_cloud_project_user_s3_credential.read_write.secret_access_key
    read_accesskey = ovh_cloud_project_user_s3_credential.read.access_key_id
    read_secretkey = ovh_cloud_project_user_s3_credential.read.secret_access_key
    rclone         = <<-EOT
      [${trimprefix(var.name, "servc-lake-")}]
      type = alias
      remote = ${trimprefix(var.name, "servc-lake-")}-main:${ovh_cloud_project_storage.datalake.name}

      [${trimprefix(var.name, "servc-lake-")}-main]
      type = s3
      provider = OVHcloud
      access_key_id = ${ovh_cloud_project_user_s3_credential.read_write.access_key_id}
      secret_access_key = ${ovh_cloud_project_user_s3_credential.read_write.secret_access_key}
      endpoint = https://s3.${lower(var.region)}.io.cloud.ovh.net
      region = ${lower(var.region)}
    EOT
    read-rclone    = <<-EOT
      [${trimprefix(var.name, "servc-lake-")}]
      type = alias
      remote = ${trimprefix(var.name, "servc-lake-")}-main:${ovh_cloud_project_storage.datalake.name}

      [${trimprefix(var.name, "servc-lake-")}-main]
      type = s3
      provider = OVHcloud
      access_key_id = ${ovh_cloud_project_user_s3_credential.read.access_key_id}
      secret_access_key = ${ovh_cloud_project_user_s3_credential.read.secret_access_key}
      endpoint = https://s3.${lower(var.region)}.io.cloud.ovh.net
      region = ${lower(var.region)}
    EOT
    warehouse      = "s3://${ovh_cloud_project_storage.datalake.name}"
  })
}
