variable "input" {
  type = string
}

provider "b2" {
  application_key    = data.vault_generic_secret.credentials.data["applicationkey"]
  application_key_id = data.vault_generic_secret.credentials.data["keyid"]
}

data "vault_generic_secret" "credentials" {
  path = var.input
}
