variable "input" {
  type = string
}

data "vault_generic_secret" "credentials" {
  path = var.input
}

provider "cloudflare" {
  api_key = data.vault_generic_secret.credentials.data["apikey"]
  email   = data.vault_generic_secret.credentials.data["email"]
}
