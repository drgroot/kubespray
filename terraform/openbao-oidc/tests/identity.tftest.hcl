mock_provider "vault" {
  mock_data "vault_generic_secret" {
    defaults = { data = { token = "test-admin-token", url = "https://openbao.example.test" } }
  }
}

mock_provider "vault" {
  alias = "admin"
  mock_data "vault_auth_backend" {
    defaults = { accessor = "auth_oidc_test" }
  }
  mock_data "vault_identity_entity" {
    defaults = { id = "existing-user-entity" }
  }
  mock_data "vault_identity_group" {
    defaults = { group_id = "existing-user-group" }
  }
}

variables {
  name         = "yusuf"
  path         = "servc/*"
  capabilities = "create,read,update,list,patch"
}

run "owner" {
  command = plan

  assert {
    condition     = vault_identity_group_alias.authelia[0].name == "yusuf" && vault_identity_group_alias.authelia[0].mount_accessor == "auth_oidc_test"
    error_message = "Authorization must use the authenticated username on the configured OIDC mount."
  }
}

run "additional_path" {
  command = plan
  variables {
    manage_identity = false
    path            = "onprem/data/authelia/yusuf"
    capabilities    = "read,update,patch"
  }
  assert {
    condition     = length(vault_identity_group.user) == 0 && length(vault_identity_group_alias.authelia) == 0 && data.vault_identity_group.user[0].group_name == "oidc-oidc-yusuf"
    error_message = "Additional path workspaces must look up the owner's group without creating another alias."
  }
}

run "blank_path" {
  command = plan
  variables {
    path = " "
  }
  expect_failures = [var.path]
}

run "empty_middle_path" {
  command = plan
  variables {
    path = "onprem/data/authelia/*, ,onprem/metadata/authelia/*"
  }
  expect_failures = [var.path]
}

run "empty_trailing_path" {
  command = plan
  variables {
    path = "onprem/data/authelia/*,"
  }
  expect_failures = [var.path]
}
