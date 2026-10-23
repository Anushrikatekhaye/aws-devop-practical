data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

locals {
  app_bucket_name = "${local.name}-app-${data.aws_caller_identity.current.account_id}"
  log_bucket_name = "${local.name}-alb-logs-${data.aws_caller_identity.current.account_id}"
}

# ------------------------------------------------------------ application bucket
resource "aws_s3_bucket" "app" {
  bucket        = local.app_bucket_name
  force_destroy = var.db_skip_final_snapshot # allow clean teardown in non-prod
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "app_bucket_tls" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.app.arn, "${aws_s3_bucket.app.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "app" {
  bucket = aws_s3_bucket.app.id
  policy = data.aws_iam_policy_document.app_bucket_tls.json

  depends_on = [aws_s3_bucket_public_access_block.app]
}

# Application artifacts pulled by instances at boot.
resource "aws_s3_object" "app_py" {
  bucket = aws_s3_bucket.app.id
  key    = "release/app.py"
  source = "${path.module}/../app/app.py"
  etag   = filemd5("${path.module}/../app/app.py")
}

resource "aws_s3_object" "requirements" {
  bucket = aws_s3_bucket.app.id
  key    = "release/requirements.txt"
  source = "${path.module}/../app/requirements.txt"
  etag   = filemd5("${path.module}/../app/requirements.txt")
}

# ------------------------------------------------------------ ALB access-log bucket
resource "aws_s3_bucket" "alb_logs" {
  bucket        = local.log_bucket_name
  force_destroy = var.db_skip_final_snapshot
}

# ALB access logs only support SSE-S3 (AES256), not KMS.
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = var.alb_log_retention_days
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid       = "AllowALBLogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.alb_logs.arn, "${aws_s3_bucket.alb_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json

  depends_on = [aws_s3_bucket_public_access_block.alb_logs]
}
