variable "name" {
  type = string
}

variable "lifecyle" {
  description = "Whether to delete non-current file versions after 60 days. Set to the string \"true\" to enable."
  type        = string
  default     = "false"
}

data "b2_account_info" "account" {

}

resource "b2_bucket" "datalake" {
  bucket_name = var.name
  bucket_type = "allPrivate"

  dynamic "lifecycle_rules" {
    for_each = var.lifecyle == "true" ? [1] : []

    content {
      file_name_prefix             = ""
      days_from_hiding_to_deleting = 60
    }
  }
}

resource "b2_application_key" "read" {
  key_name     = "${var.name}-read"
  bucket_id    = b2_bucket.datalake.bucket_id
  capabilities = ["listBuckets", "listFiles", "readFiles"]
}

resource "b2_application_key" "read_write" {
  key_name  = "${var.name}-read-write"
  bucket_id = b2_bucket.datalake.bucket_id
  capabilities = [
    "listBuckets",
    "listFiles",
    "readFiles",
    "writeFiles",
    "deleteFiles",
  ]
}
