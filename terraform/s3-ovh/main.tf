variable "name" {
  type = string
}

variable "region" {
  description = "OVHcloud Object Storage region."
  type        = string
  default     = "BHS"
}

locals {
  project = data.vault_generic_secret.credentials.data["project"]

  bucket_arn = "arn:aws:s3:::${ovh_cloud_project_storage.datalake.name}"
}

resource "ovh_cloud_project_storage" "datalake" {
  service_name = local.project
  region_name  = upper(var.region)
  name         = var.name
}

resource "ovh_cloud_project_user" "read_write" {
  service_name = local.project
  description  = "${var.name}-read-write"
  role_names   = ["objectstore_operator"]
}

resource "ovh_cloud_project_user" "read" {
  service_name = local.project
  description  = "${var.name}-read"
  role_names   = ["objectstore_operator"]
}

resource "ovh_cloud_project_user_s3_policy" "read_write" {
  service_name = local.project
  user_id      = ovh_cloud_project_user.read_write.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions",
        ]
        Resource = local.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject",
        ]
        Resource = "${local.bucket_arn}/*"
      },
    ]
  })
}

resource "ovh_cloud_project_user_s3_policy" "read" {
  service_name = local.project
  user_id      = ovh_cloud_project_user.read.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketVersions",
        ]
        Resource = local.bucket_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
        ]
        Resource = "${local.bucket_arn}/*"
      },
    ]
  })
}

resource "ovh_cloud_project_user_s3_credential" "read_write" {
  service_name = local.project
  user_id      = ovh_cloud_project_user.read_write.id
}

resource "ovh_cloud_project_user_s3_credential" "read" {
  service_name = local.project
  user_id      = ovh_cloud_project_user.read.id
}
