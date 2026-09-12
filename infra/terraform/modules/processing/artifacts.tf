# Self-contained .NET deployment packages (the .NET runtime bundled in,
# since provided.al2023 has none preinstalled — see lambdas.tf) routinely
# exceed the 50MB direct-upload limit for CreateFunction/UpdateFunctionCode.
# Staging the ZIP in S3 first sidesteps that: Lambda pulls it from here
# instead of receiving it in the API request body.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "doclens-lambda-artifacts-${data.aws_caller_identity.current.account_id}-${var.environment}"
  force_destroy = true # deployment packages, not data worth preserving
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "lambda_zip" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "doclens-lambda-${filesha256(var.lambda_zip_path)}.zip"
  source = var.lambda_zip_path
  etag   = filemd5(var.lambda_zip_path)
}
