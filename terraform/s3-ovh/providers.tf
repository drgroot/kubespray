variable "input" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.input
}

provider "ovh" {
  endpoint           = "ovh-ca"
  application_key    = data.vault_generic_secret.credentials.data["application-key"]
  application_secret = data.vault_generic_secret.credentials.data["application-secret"]
  consumer_key       = data.vault_generic_secret.credentials.data["consumer-key"]
}
