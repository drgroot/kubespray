mock_provider "vault" {
  mock_data "vault_generic_secret" {
    defaults = { data = {
      token                 = "test-admin-token", url = "https://openbao.example.test",
      client-secret-openbao = "generated-client-secret"
    } }
  }
}
mock_provider "vault" {
  alias = "admin"
}
variables {
  oidc_discovery_url      = "https://auth.example.test"
  oidc_client_id          = "openbao"
  oidc_client_secret_path = "onprem/dynamic/authelia-client-creds"
  oidc_client_secret_key  = "client-secret-openbao"
  openbao_url             = "https://openbao.example.test"
}
run "configure_authelia_login" {
  command = apply
  assert {
    condition     = vault_jwt_auth_backend.oidc.oidc_client_id == "openbao" && vault_jwt_auth_backend.oidc.oidc_client_secret == "generated-client-secret"
    error_message = "Configure OpenBao using the generated Authelia client secret."
  }
}
