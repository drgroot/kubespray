data "vault_generic_secret" "versions" {
  path = "kubernetes/VERSIONS"
}

locals {
  versions = nonsensitive(jsondecode(data.vault_generic_secret.versions.data_json))
}
