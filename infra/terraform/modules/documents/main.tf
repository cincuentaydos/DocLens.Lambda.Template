# Document storage — S3 with versioning ENABLED (protects the original per
# ADR-013's DR strategy; the previous design had this disabled) + GuardDuty
# Malware Protection for S3 (ADR-004). The scan-result → EventBridge → SQS
# wiring lives in modules/processing (ADR-011) since it also needs the queue.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "documents" {
  bucket = "doclens-documents-${data.aws_caller_identity.current.account_id}-${var.environment}"
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  cors_rule {
    allowed_methods = ["PUT"]
    allowed_origins = var.frontend_origins
    allowed_headers = ["Content-Type"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_policy" "enforce_ssl" {
  bucket = aws_s3_bucket.documents.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyNonSSL"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.documents.arn,
        "${aws_s3_bucket.documents.arn}/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

# --- GuardDuty Malware Protection for S3 (ADR-004) ---
# NOTE: aws_guardduty_malware_protection_plan is a comparatively new resource
# type (standalone S3 malware protection, not the classic EC2 GuardDuty
# detector). Verify its exact schema against the pinned provider version at
# `terraform validate` time — see ADR-002's note on provider lag.

resource "aws_iam_role" "guardduty_malware_protection" {
  name = "doclens-guardduty-malware-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "malware-protection-plan.guardduty.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "guardduty_malware_protection" {
  name = "doclens-guardduty-malware-${var.environment}"
  role = aws_iam_role.guardduty_malware_protection.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectTagging"]
        Resource = "${aws_s3_bucket.documents.arn}/*"
      },
      {
        Sid      = "S3Tag"
        Effect   = "Allow"
        Action   = ["s3:PutObjectTagging", "s3:PutObjectVersionTagging"]
        Resource = "${aws_s3_bucket.documents.arn}/*"
      },
      {
        Sid      = "S3List"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.documents.arn
      }
    ]
  })
}

resource "aws_guardduty_malware_protection_plan" "documents" {
  role = aws_iam_role.guardduty_malware_protection.arn

  protected_resource {
    s3_bucket {
      bucket_name = aws_s3_bucket.documents.id
    }
  }

  depends_on = [aws_iam_role_policy.guardduty_malware_protection]
}
