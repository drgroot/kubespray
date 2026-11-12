# OpenTofu 1.10.x overrides whole resources, not for_each instances.
# Instance references are still valid in the assertions below.
mock_provider "vault" {
  mock_data "vault_generic_secret" {
    defaults = { data = { id = "test-session-token" } }
  }
}

mock_provider "external" {
  mock_data "external" {
    defaults = {
      result = {
        address = "aHR0cHM6Ly9vcGVuYmFvLmV4YW1wbGUudGVzdA=="
        ca_file = ""
      }
    }
  }
}

mock_provider "http" {
  mock_data "http" {
    defaults = {
      status_code   = 404
      response_body = "{\"errors\":[]}"
    }
  }
}

mock_provider "random" {
  mock_resource "random_password" {
    defaults = { result = "abc123generated" }
  }
}

variables {
  name         = "postgres"
  input        = "onprem/vendor/postgres"
  properties   = "root-username,root-password"
  value-types  = "username,password"
  specialchars = "no,no"
  output       = "none"
}

run "initialize_missing_record" {
  command = apply

  assert {
    condition     = vault_generic_endpoint.initialize[0].path == "onprem/data/vendor/postgres" && jsondecode(vault_generic_endpoint.initialize[0].data_json).options.cas == 0
    error_message = "A missing record must be created at the KV v2 API path with CAS=0."
  }
  assert {
    condition     = jsondecode(vault_generic_endpoint.initialize[0].data_json).data["root-username"] == "postgresabc123generated" && jsondecode(vault_generic_endpoint.initialize[0].data_json).data["root-password"] == "abc123generated"
    error_message = "Generate values with the requested types and property names."
  }
  assert {
    condition     = !random_password.generated["root-username"].special && !random_password.generated["root-password"].special && length(vault_generic_endpoint.output) == 0
    error_message = "Respect no,no special-character flags and output=none."
  }
  assert {
    condition     = vault_generic_endpoint.initialize[0].disable_delete
    error_message = "Removing initializer state must never delete the remote credential record."
  }
}

run "preserve_existing_empty_and_null_properties" {
  command = plan

  override_data {
    target = data.http.current
    values = {
      status_code   = 200
      response_body = <<-JSON
        {"data":{"data":{"root-username":"","root-password":null,"neighbor":"keep"},"metadata":{"version":5}}}
      JSON
    }
  }

  assert {
    condition     = length(vault_generic_endpoint.initialize) == 0 && length(random_password.generated) == 0
    error_message = "Property presence, including empty and null values, must suppress generation and writes."
  }
}

run "preserve_neighbors_and_use_the_data_snapshot_version" {
  command = apply

  override_data {
    target = data.http.current
    values = {
      status_code   = 200
      response_body = <<-JSON
        {"data":{"data":{"root-username":"manually-set","neighbor":"keep"},"metadata":{"version":7}}}
      JSON
    }
  }
  override_data {
    target = data.http.metadata
    values = {
      status_code   = 200
      response_body = "{\"data\":{\"current_version\":8}}"
    }
  }

  assert {
    condition     = length(random_password.generated) == 1 && jsondecode(vault_generic_endpoint.initialize[0].data_json).data["root-username"] == "manually-set" && jsondecode(vault_generic_endpoint.initialize[0].data_json).data.neighbor == "keep"
    error_message = "Generate only missing properties and preserve all neighboring data."
  }
  assert {
    condition     = jsondecode(vault_generic_endpoint.initialize[0].data_json).options.cas == 7
    error_message = "CAS must use the version of the values read, never a newer separately read metadata version."
  }
}

run "optional_output_is_also_initialize_only" {
  command = apply
  variables {
    output       = "onprem/initial/postgres"
    specialchars = "yes,no"
  }

  assert {
    condition     = vault_generic_endpoint.output[0].path == "onprem/data/initial/postgres" && jsondecode(vault_generic_endpoint.output[0].data_json).data == jsondecode(vault_generic_endpoint.initialize[0].data_json).data
    error_message = "Initialize an explicitly requested output with the selected input values."
  }
  assert {
    condition     = random_password.generated["root-username"].special && !random_password.generated["root-password"].special && vault_generic_endpoint.output[0].disable_delete
    error_message = "Respect each property's independent flags and retain output values on deletion."
  }
}

run "reject_mismatched_value_types" {
  command = plan
  variables {
    value-types = "username"
  }
  expect_failures = [var.value-types]
}

run "reject_invalid_special_character_flag" {
  command = plan
  variables {
    specialchars = "maybe,no"
  }
  expect_failures = [var.specialchars]
}

run "authorization_failure_is_not_a_missing_record" {
  command = plan
  override_data {
    target = data.http.current
    values = {
      status_code   = 403
      response_body = "{\"errors\":[\"permission denied\"]}"
    }
  }
  expect_failures = [data.http.current]
}

run "reject_record_created_during_read" {
  command = plan
  override_data {
    target = data.http.metadata
    values = {
      status_code   = 200
      response_body = <<-JSON
        {"data":{"current_version":1,"versions":{"1":{"deletion_time":"","destroyed":false}}}}
      JSON
    }
  }
  expect_failures = [vault_generic_endpoint.initialize]
}
