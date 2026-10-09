# Scenarios:
# - owner (normal): username grants its own external-group policy without a UUID input.
# - additional_path (normal): a second workspace adds a policy to the existing user's group.
# - another_user (normal): a different username selects a separate group and policy.

mock_provider "vault" {
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

# Scenario: owner. Input: name=yusuf, no UUID. Expected: external group with
# alias yusuf and nonexclusive policies, allowing the OIDC sub to remain opaque.
run "owner" {
  command = plan

  assert {
    condition     = vault_identity_group.user[0].name == "oidc-oidc-yusuf" && vault_identity_group.user[0].type == "external" && vault_identity_group.user[0].external_policies
    error_message = "The owner must create a per-user external group with externally managed policies."
  }
  assert {
    condition     = vault_identity_group_alias.authelia[0].name == "yusuf" && vault_identity_group_alias.authelia[0].mount_accessor == "auth_oidc_test"
    error_message = "Authorization must use the authenticated username on the configured OIDC mount."
  }
  assert {
    condition     = !vault_identity_group_policies.user_path.exclusive && vault_identity_group_policies.user_path.policies == toset(["oidc-yusuf-servc-"])
    error_message = "Only this user's path policy should be attached, without replacing their other policies."
  }
}

# Scenario: additional_path. Input: manage_identity=false and a second path.
# Expected: reuse the named group and create no competing group or alias.
run "additional_path" {
  command = plan
  variables {
    manage_identity = false
    path            = "external-infra/data/authelia/yusuf"
    capabilities    = "read,update,patch"
  }
  assert {
    condition     = length(vault_identity_group.user) == 0 && length(vault_identity_group_alias.authelia) == 0 && data.vault_identity_group.user[0].group_name == "oidc-oidc-yusuf"
    error_message = "Additional path workspaces must look up the owner's group without creating another alias."
  }
  assert {
    condition     = vault_identity_group_policies.user_path.group_id == "existing-user-group" && !vault_identity_group_policies.user_path.exclusive
    error_message = "The second policy must be added to the existing group without replacing the first."
  }
}

# Scenario: another_user. Input: name=salihah and her own secret path.
# Expected: a separate alias/group and no Yusuf servc policy attachment.
run "another_user" {
  command = plan
  variables {
    name         = "salihah"
    path         = "external-infra/data/authelia/salihah"
    capabilities = "read,update,patch"
  }
  assert {
    condition     = vault_identity_group.user[0].name == "oidc-oidc-salihah" && vault_identity_group_alias.authelia[0].name == "salihah" && vault_identity_group_policies.user_path.policies == toset(["oidc-salihah-external-infra-data-authelia-salihah"])
    error_message = "A different username must receive a separate group and only its own policy."
  }
}
