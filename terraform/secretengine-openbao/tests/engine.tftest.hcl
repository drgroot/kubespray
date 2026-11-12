mock_provider "vault" {
  mock_data "vault_kv_secret_v2" {
    defaults = {
      data = {
        username  = "openbao-admin"
        token     = "test-admin-token"
        url       = "https://openbao.example.test:8200"
        "ca-cert" = "test-ca-pem"
      }
    }
  }
}

mock_provider "vault" {
  alias = "admin"
}

variables {
  name   = "servc"
  input  = "onprem/dynamic/vault-root"
  output = "none"
}

run "create_engine_without_publishing" {
  command = plan

  assert {
    condition     = data.vault_kv_secret_v2.input.mount == "onprem" && data.vault_kv_secret_v2.input.name == "dynamic/vault-root"
    error_message = "Read the root record as a logical KV v2 path, not as a raw API path."
  }

  assert {
    condition     = vault_mount.engine.path == "servc" && vault_mount.engine.type == "kv" && vault_mount.engine.options["version"] == "2"
    error_message = "Create the named engine with KV version 2."
  }

  assert {
    condition     = length(vault_kv_secret_v2.output) == 0
    error_message = "output=none must not publish the admin credential."
  }
}

run "publish_owner_credentials_when_requested" {
  command = plan

  variables {
    output = "servc/bootstrap/root"
  }

  assert {
    condition     = vault_kv_secret_v2.output[0].mount == "servc" && vault_kv_secret_v2.output[0].name == "bootstrap/root"
    error_message = "Publish to the requested logical KV v2 output path."
  }

  assert {
    condition     = jsondecode(vault_kv_secret_v2.output[0].data_json)["token"] == "test-admin-token" && jsondecode(vault_kv_secret_v2.output[0].data_json)["username"] == "openbao-admin"
    error_message = "Preserve the input owner's token and username instead of treating the token as a userpass password."
  }
}

run "reject_incomplete_root_record" {
  command = plan

  override_data {
    target = data.vault_kv_secret_v2.input
    values = {
      data = {
        username  = "openbao-admin"
        url       = "https://openbao.example.test:8200"
        "ca-cert" = "test-ca-pem"
      }
    }
  }

  expect_failures = [data.vault_kv_secret_v2.input]
}
