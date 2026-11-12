locals {
  property_names = [for key in split(",", var.properties) : trimspace(key)]
  value_types    = [for kind in split(",", var.value-types) : lower(trimspace(kind))]
  special_flags  = [for flag in split(",", var.specialchars) : lower(trimspace(flag)) == "yes"]
  property_specs = {
    for index, key in local.property_names : key => {
      kind    = try(local.value_types[index], "password")
      special = try(local.special_flags[index], false)
    }
  }
  targets = merge(
    { input = var.input },
    var.output == "none" || var.output == var.input ? {} : { output = var.output }
  )
  target_mounts = { for key, path in local.targets : key => split("/", path)[0] }
  target_names = {
    for key, path in local.targets : key => join("/", slice(split("/", path), 1, length(split("/", path))))
  }
  api_paths = {
    for key, path in local.targets : key => {
      data = join("/", concat(
        [replace(urlencode(local.target_mounts[key]), "+", "%20"), "data"],
        [for segment in split("/", local.target_names[key]) : replace(urlencode(segment), "+", "%20")]
      ))
      metadata = join("/", concat(
        [replace(urlencode(local.target_mounts[key]), "+", "%20"), "metadata"],
        [for segment in split("/", local.target_names[key]) : replace(urlencode(segment), "+", "%20")]
      ))
    }
  }
}

# Read only the connection settings from the runner environment. Base64 keeps
# their JSON representation safe without requiring Python or jq in the image.
data "external" "connection" {
  program = ["sh", "-ec", <<-SHELL
    : "$${VAULT_ADDR:?VAULT_ADDR must be set}"
    address=$(printf '%s' "$VAULT_ADDR" | base64 | tr -d '\n')
    ca_file=$(printf '%s' "$${VAULT_CACERT:-}" | base64 | tr -d '\n')
    printf '{"address":"%s","ca_file":"%s"}\n' "$address" "$ca_file"
  SHELL
  ]
}

# Reuse the provider's short-lived userpass session for reads that may return
# 404. The normal KV data source treats a missing record as an error.
data "vault_generic_secret" "session" {
  path = "auth/token/lookup-self"
}

locals {
  address = trimsuffix(base64decode(data.external.connection.result.address), "/")
  ca_file = base64decode(data.external.connection.result.ca_file)
  ca_pem  = local.ca_file == "" ? null : file(local.ca_file)
}

data "http" "current" {
  for_each = local.targets

  url         = "${local.address}/v1/${local.api_paths[each.key].data}"
  ca_cert_pem = local.ca_pem
  request_headers = {
    X-Vault-Token = data.vault_generic_secret.session.data["id"]
  }

  lifecycle {
    postcondition {
      condition     = contains([200, 404], self.status_code)
      error_message = "Reading the KV record failed. Only a missing record (404) may be initialized; authorization and server errors must not be treated as absence."
    }
  }
}

data "http" "metadata" {
  for_each = local.targets

  url         = "${local.address}/v1/${local.api_paths[each.key].metadata}"
  ca_cert_pem = local.ca_pem
  request_headers = {
    X-Vault-Token = data.vault_generic_secret.session.data["id"]
  }

  lifecycle {
    postcondition {
      condition     = contains([200, 404], self.status_code)
      error_message = "Reading KV metadata failed. Metadata access is required for a safe check-and-set write."
    }
  }
}

locals {
  existing = {
    for key, response in data.http.current : key => sensitive(
      try(jsondecode(response.response_body).data.data, {})
    )
  }
  # Use the version returned WITH the values. Reading a newer metadata version
  # and combining it with older values could otherwise lose concurrent edits.
  versions = {
    for key, response in data.http.current : key => (
      response.status_code == 200 ? jsondecode(response.response_body).data.metadata.version :
      (data.http.metadata[key].status_code == 200 ? jsondecode(data.http.metadata[key].response_body).data.current_version : 0)
    )
  }
  snapshot_safe = {
    for key, response in data.http.current : key => (
      response.status_code == 200 || local.versions[key] == 0 ||
      try(jsondecode(data.http.metadata[key].response_body).data.versions[tostring(local.versions[key])].deletion_time != "", false) ||
      try(jsondecode(data.http.metadata[key].response_body).data.versions[tostring(local.versions[key])].destroyed, false)
    )
  }
  missing = {
    for key, target in local.targets : key => setsubtract(
      toset(local.property_names), nonsensitive(toset(keys(local.existing[key])))
    )
  }
}

resource "random_password" "generated" {
  for_each = {
    for key, spec in local.property_specs : key => spec
    if contains(local.missing["input"], key)
  }

  length           = each.value.kind == "username" ? 20 : 32
  upper            = each.value.kind == "password"
  lower            = true
  numeric          = true
  special          = each.value.special
  min_lower        = 1
  min_numeric      = 1
  min_special      = each.value.special ? 1 : 0
  override_special = "-_."
}

locals {
  seed_values = merge(local.existing["input"], {
    for key, generated in random_password.generated : key => (
      local.property_specs[key].kind == "username" ? "${replace(var.name, "_", "")}${generated.result}" : generated.result
    )
  })
  initial_data = {
    for key, target in local.targets : key => jsonencode({
      options = { cas = local.versions[key] }
      data = merge(local.existing[key], {
        for property in local.missing[key] : property => local.seed_values[property]
      })
    })
  }
}

# A changed version/missing-key set permits retrying a property that was removed
# before the previous initializer had been retired from Terraform state.
resource "terraform_data" "observation" {
  for_each = local.targets
  input = {
    version = local.versions[each.key]
    missing = local.missing[each.key]
  }
}

resource "vault_generic_endpoint" "initialize" {
  count = length(local.missing["input"]) > 0 ? 1 : 0

  path                 = "${local.target_mounts["input"]}/data/${local.target_names["input"]}"
  data_json            = local.initial_data["input"]
  disable_delete       = true
  ignore_absent_fields = true

  lifecycle {
    ignore_changes       = [data_json]
    replace_triggered_by = [terraform_data.observation]
    precondition {
      condition     = local.snapshot_safe["input"]
      error_message = "The input record appeared while it was being read. Retry with a fresh plan; existing data will not be overwritten."
    }
  }
}

resource "vault_generic_endpoint" "output" {
  count = length(lookup(local.missing, "output", [])) > 0 ? 1 : 0

  path                 = "${local.target_mounts["output"]}/data/${local.target_names["output"]}"
  data_json            = local.initial_data["output"]
  disable_delete       = true
  ignore_absent_fields = true

  lifecycle {
    ignore_changes       = [data_json]
    replace_triggered_by = [terraform_data.observation]
    precondition {
      condition     = local.snapshot_safe["output"]
      error_message = "The output record appeared while it was being read. Retry with a fresh plan; existing data will not be overwritten."
    }
  }

  depends_on = [vault_generic_endpoint.initialize]
}
