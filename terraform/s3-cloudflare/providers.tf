variable "input" {
  type = string
}

provider "cloudflare" {
  email   = data.vault_generic_secret.credentials.data["email"]
  api_key = data.vault_generic_secret.credentials.data["apikey"]
}

data "vault_generic_secret" "credentials" {
  path = var.input
}
