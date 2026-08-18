variable "input" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.input
}

provider "minio" {
  minio_server   = trimprefix(trimprefix(data.vault_generic_secret.credentials.data["endpoint-url"], "https://"), "http://")
  minio_user     = data.vault_generic_secret.credentials.data["root-access-key"]
  minio_password = data.vault_generic_secret.credentials.data["root-secret-key"]
  minio_region   = data.vault_generic_secret.credentials.data["region"]
  minio_ssl      = startswith(data.vault_generic_secret.credentials.data["endpoint-url"], "https://")
}
