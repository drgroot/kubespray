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
  mock_data "vault_auth_backend" {
    defaults = { accessor = "auth_userpass_test" }
  }
  mock_data "vault_generic_secret" {
    defaults = { data_json = "{\"by_namespace\":[],\"total\":0}" }
  }
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

run "unlock_locked_servc" {
  command = apply
  variables {
    name        = "servc"
    usernamekey = null
  }
  override_data {
    target = data.vault_generic_secret.locked_users
    values = {
      data_json = "{\"by_namespace\": [{\"namespace_id\": \"root\", \"mount_accessors\": [{\"mount_accessor\": \"auth_userpass_test\", \"alias_identifiers\": [\"servc\", \"another-user\"]}]}]}"
    }
  }
  assert {
    condition     = length(vault_generic_endpoint.unlock_user) == 1 && vault_generic_endpoint.unlock_user[0].path == "sys/locked-users/auth_userpass_test/unlock/servc" && vault_generic_endpoint.unlock_user[0].disable_read && vault_generic_endpoint.unlock_user[0].disable_delete
    error_message = "Unlock only the configured user through the write-only unlock endpoint."
  }
}

run "ignore_other_mount_lockout" {
  command = apply
  override_data {
    target = data.vault_generic_secret.locked_users
    values = {
      data_json = "{\"by_namespace\": [{\"namespace_id\": \"root\", \"mount_accessors\": [{\"mount_accessor\": \"auth_ldap_test\", \"alias_identifiers\": [\"service\"]}]}]}"
    }
  }
  assert {
    condition     = length(vault_generic_endpoint.unlock_user) == 0
    error_message = "A user locked on another auth mount must not trigger a userpass unlock."
  }
}

run "ignore_another_user_lockout" {
  command = apply
  override_data {
    target = data.vault_generic_secret.locked_users
    values = {
      data_json = "{\"by_namespace\":[{\"mount_accessors\":[{\"mount_accessor\":\"auth_userpass_test\",\"alias_identifiers\":[\"another-user\"]}]}]}"
    }
  }
  assert {
    condition     = length(vault_generic_endpoint.unlock_user) == 0
    error_message = "Another user's lockout on the same mount must remain untouched."
  }
}

run "empty_lockout_response" {
  command = apply
  override_data {
    target = data.vault_generic_secret.locked_users
    values = {
      data_json = "{\"by_namespace\":null,\"total\":0}"
    }
  }
  assert {
    condition     = length(vault_generic_endpoint.unlock_user) == 0
    error_message = "An empty lockout response must not create an unlock request."
  }
}

run "readonly_ci_user" {
  command = apply
  variables {
    name                 = "openbao-ci"
    usernamekey          = null
    path                 = "onprem/data/vendor/docker,onprem/data/dynamic/docker-mirror,servc/data/iac/coder-onpremise"
    capabilities         = "read"
    allow_token_creation = false
    no_default_policy    = true
  }
  assert {
    condition     = vault_generic_endpoint.userpass_user.path == "auth/userpass/users/openbao-ci" && jsondecode(vault_generic_endpoint.userpass_user.data_json).token_no_default_policy && vault_token.user.no_default_policy && vault_token.user.metadata.username == "openbao-ci" && vault_token.user.policies == toset(["openbao-user-openbao-ci"])
    error_message = "CI login and managed tokens must identify openbao-ci and exclude the default policy."
  }
  assert {
    condition     = replace(vault_policy.user.policy, "/\\s+/", "") == replace("path \"onprem/data/vendor/docker\" { capabilities = [\"read\"] }path \"onprem/data/dynamic/docker-mirror\" { capabilities = [\"read\"] }path \"servc/data/iac/coder-onpremise\" { capabilities = [\"read\"] }path \"auth/token/lookup-self\" { capabilities = [\"read\"] }", "/\\s+/", "")
    error_message = "CI must read only the three exact workflow secret paths and its own token metadata, without child-token creation."
  }
}
