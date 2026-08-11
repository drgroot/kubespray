variable "name" {
  type = string
}

variable "account_id" {
  description = "account id"
  type        = string
  default     = "59746b0636a0daf97ac4598137200fbd"
}

resource "cloudflare_r2_bucket" "lake" {
  account_id    = var.account_id
  name          = var.name
  location      = "ENAM"
  storage_class = "Standard"
}

data "cloudflare_api_token_permission_groups_list" "this" {
}

locals {

  r2_api_permissions = { for x in data.cloudflare_api_token_permission_groups_list.this.result : x.name => x.id if contains(["Workers R2 Storage Bucket Item Read", "Workers R2 Storage Bucket Item Write"], x.name) }

  permission_id_list = compact([
    local.r2_api_permissions["Workers R2 Storage Bucket Item Write"],
  ])
}

resource "cloudflare_api_token" "token" {
  name = var.name

  policies = [{
    effect = "allow"
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${var.account_id}_${cloudflare_r2_bucket.lake.jurisdiction}_${cloudflare_r2_bucket.lake.name}" = "*"
    })
    permission_groups = [for x in local.permission_id_list : { id = x }]
  }]
}

resource "cloudflare_account_token" "write" {
  account_id = var.account_id
  name       = var.name
  policies = [
    {
      effect = "allow",
      permission_groups = [
        {
          id = "2efd5506f9c8494dacb1fa10a3e7d5b6",
          meta = {
            key   = "name"
            value = "Workers R2 Storage Bucket Item Write"
          }
        }
      ]
      resources = jsonencode({
        "com.cloudflare.edge.r2.bucket.${var.account_id}_${cloudflare_r2_bucket.lake.jurisdiction}_${cloudflare_r2_bucket.lake.name}" = "*"
      })
    }
  ]
}

resource "cloudflare_account_token" "read" {
  account_id = var.account_id
  name       = "${var.name}-read"
  policies = [
    {
      effect = "allow",
      permission_groups = [
        {
          id = local.r2_api_permissions["Workers R2 Storage Bucket Item Read"],
          meta = {
            key   = "name"
            value = "Workers R2 Storage Bucket Item Read"
          }
        }
      ]
      resources = jsonencode({
        "com.cloudflare.edge.r2.bucket.${var.account_id}_${cloudflare_r2_bucket.lake.jurisdiction}_${cloudflare_r2_bucket.lake.name}" = "*"
      })
    }
  ]
}
