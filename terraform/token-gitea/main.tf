variable "name" {
  type = string
}

locals {
  gitea_username = var.name
}

# Match user-openbao's effective renewal cadence: a 24-hour lifetime renewed
# when fewer than 12 hours remain. Crossplane reconciliation drives rotation.
resource "time_rotating" "user" {
  rotation_hours = 12
}

resource "gitea_token" "user" {
  # Gitea requires unique names, including while both generations are valid.
  name   = "${local.gitea_username}-opentofu-${time_rotating.user.unix}"
  scopes = ["all"]

  lifecycle {
    create_before_destroy = true
  }
}

# Wait after publishing to OpenBao, including on the initial migration. The
# token's create_before_destroy ordering keeps its previous generation until
# dependent resources finish updating. Replace this guard for each token so
# every rotation allows consumers time to refresh before revocation.
resource "time_sleep" "credential_propagation" {
  depends_on = [vault_generic_secret.connection]

  create_duration = "5m"
  triggers = {
    token_id = gitea_token.user.id
  }

  lifecycle {
    create_before_destroy = true
  }
}
