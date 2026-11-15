mock_provider "gitea" {}
mock_provider "time" {}
mock_provider "vault" {
  mock_data "vault_generic_secret" {
    defaults = { data = { service = "test-password", root-username = "gitea-admin", root-password = "test-admin-password" } }
  }
}

variables {
  name           = "service"
  credentialpath = "onprem/dynamic/gitea-user-creds"
  passwordkey    = "service"
  gitea_url      = "https://gitea.example.test"
  output         = "onprem/dynamic/gitea-service"
}

run "publish_initial_token" {
  command = apply

  override_resource {
    target = time_rotating.user
    values = { unix = 100 }
  }

  assert {
    condition     = gitea_token.user.name == "service-opentofu-100"
    error_message = "Token names must distinguish generations so replacement can precede revocation."
  }

  assert {
    condition     = jsondecode(vault_generic_secret.connection.data_json).token == gitea_token.user.token && jsondecode(vault_generic_secret.connection.data_json).password == "test-password"
    error_message = "Publish the active token while preserving the existing credentials schema."
  }
}

run "publish_replacement_token" {
  command = apply

  override_resource {
    target = time_rotating.user
    values = { unix = 200 }
  }

  assert {
    condition     = gitea_token.user.name == "service-opentofu-200" && jsondecode(vault_generic_secret.connection.data_json).token == gitea_token.user.token && time_sleep.credential_propagation.triggers.token_id == gitea_token.user.id
    error_message = "A new rotation timestamp must replace the token, publish it, and update the retirement guard."
  }
}

run "publish_admin_token" {
  command = apply

  variables {
    name           = "keda"
    usernamekey    = "root-username"
    passwordkey    = "root-password"
    credentialpath = "onprem/vendor/gitea"
    output         = "onprem/dynamic/gitea-keda"
  }

  assert {
    condition     = local.gitea_username == "gitea-admin" && jsondecode(vault_generic_secret.connection.data_json).username == "gitea-admin" && jsondecode(vault_generic_secret.connection.data_json).password == "test-admin-password"
    error_message = "Admin tokens must authenticate and publish using the username from the credential secret."
  }

  assert {
    condition     = startswith(gitea_token.user.name, "keda-opentofu-") && jsondecode(vault_generic_secret.connection.data_json).token == gitea_token.user.token
    error_message = "The admin token must keep a distinct KEDA rotation name and publish the active token."
  }
}
