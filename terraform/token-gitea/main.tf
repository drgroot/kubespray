variable "name" {
  type = string
}

locals {
  gitea_username = var.name
}

resource "gitea_token" "user" {
  name   = "${local.gitea_username}-opentofu"
  scopes = ["all"]
}
