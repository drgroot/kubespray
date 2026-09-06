# Accepted for compatibility with the shared Crossplane Workspace interface.
variable "name" {
  type    = string
  default = "vault-oidc"
}

variable "input" {
  type    = string
  default = ""
}

variable "output" {
  type    = string
  default = ""
}

variable "oidc_discovery_url" {
  type = string
}

variable "oidc_client_id" {
  type = string
}

variable "oidc_client_secret_path" {
  type = string
}

variable "oidc_client_secret_key" {
  type = string
}

variable "vault_url" {
  type = string
}

data "vault_generic_secret" "oidc_client" {
  path = var.oidc_client_secret_path
}

resource "vault_jwt_auth_backend" "oidc" {
  path                = "oidc"
  type                = "oidc"
  description         = "Authelia OIDC"
  oidc_discovery_url  = var.oidc_discovery_url
  oidc_client_id      = var.oidc_client_id
  oidc_client_secret  = data.vault_generic_secret.oidc_client.data[var.oidc_client_secret_key]
  bound_issuer        = var.oidc_discovery_url
  default_role        = "default"
}

resource "vault_jwt_auth_backend_role" "default" {
  backend         = vault_jwt_auth_backend.oidc.path
  role_name       = "default"
  role_type       = "oidc"
  user_claim      = "sub"
  groups_claim    = "groups"
  oidc_scopes     = ["profile", "email", "groups"]
  token_policies  = ["default"]

  allowed_redirect_uris = [
    "${var.vault_url}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
}
