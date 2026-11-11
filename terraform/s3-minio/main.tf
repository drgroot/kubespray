variable "name" {
  type = string
}

resource "minio_s3_bucket" "datalake" {
  bucket = var.name
  acl    = "private"
}

resource "minio_iam_user" "datalake" {
  name = var.name
}

resource "minio_iam_user" "read" {
  name = "${var.name}-read"
}

resource "minio_iam_policy" "datalake" {
  name = "${var.name}-read-write"

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
        Resource = minio_s3_bucket.datalake.arn
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
        Resource = "${minio_s3_bucket.datalake.arn}/*"
      },
    ]
  })
}

resource "minio_iam_policy" "read" {
  name = "${var.name}-read"

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
        Resource = minio_s3_bucket.datalake.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
        ]
        Resource = "${minio_s3_bucket.datalake.arn}/*"
      },
    ]
  })
}

resource "minio_iam_user_policy_attachment" "datalake" {
  user_name   = minio_iam_user.datalake.id
  policy_name = minio_iam_policy.datalake.id
}

resource "minio_iam_user_policy_attachment" "read" {
  user_name   = minio_iam_user.read.id
  policy_name = minio_iam_policy.read.id
}
