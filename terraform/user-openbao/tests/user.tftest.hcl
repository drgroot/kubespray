mock_provider "vault" {
  mock_data "vault_generic_secret" {
    defaults = { data = {
      token            = "test-admin-token", url = "https://openbao.example.test",
      service-username = "service", service-password = "service-password"
    } }
  }
}
mock_provider "vault" {
  alias = "admin"
  mock_resource "vault_token" {
    defaults = { client_token = "service-token" }
  }
}
variables {
  name         = "service"
  input        = "onprem/vendor/service"
  output       = "onprem/dynamic/service"
  usernamekey  = "service-username"
  passwordkey  = "service-password"
  openbao_addr = "https://openbao.example.test"
  path         = "servc/*"
  capabilities = "create,read,update,list,patch"
}
run "provision_scoped_user" {
  command = apply
  assert {
    condition     = vault_generic_endpoint.userpass_user.path == "auth/userpass/users/service" && jsondecode(vault_generic_endpoint.userpass_user.data_json).password == "service-password"
    error_message = "Provision the named userpass account with its input password."
  }
  assert {
    condition     = vault_token.user.policies == toset(["openbao-user-service"]) && strcontains(vault_policy.user.policy, "servc/*") && !strcontains(vault_policy.user.policy, "openbao-admin")
    error_message = "The service user's token must receive only its scoped policy, never the admin policy."
  }
  assert {
    condition     = vault_generic_secret.output.path == "onprem/dynamic/service" && jsondecode(vault_generic_secret.output.data_json).token == "service-token" && jsondecode(vault_generic_secret.output.data_json)["vault-addr"] == "https://openbao.example.test"
    error_message = "Publish the user credentials and token with the legacy module's output schema."
  }
}

run "fixed_servc_username" {
  command = apply
  variables {
    name        = "servc"
    usernamekey = null
  }
  assert {
    condition     = vault_generic_endpoint.userpass_user.path == "auth/userpass/users/servc" && jsondecode(vault_generic_secret.output.data_json).username == "servc"
    error_message = "When only a password is generated, provision and publish the explicit account name."
  }
}
