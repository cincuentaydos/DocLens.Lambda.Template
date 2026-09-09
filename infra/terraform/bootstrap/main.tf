# One-time bootstrap for the Terraform remote state backend.
#
# This config uses LOCAL state on purpose — it creates the S3 bucket and
# DynamoDB lock table that the root module's "s3" backend depends on, so it
# cannot itself depend on that backend (chicken-and-egg).
#
# Usage (once per AWS account, run manually with your own credentials):
#   cd infra/terraform/bootstrap
#   terraform init
#   terraform apply
#
# After this succeeds, the root module's backend "s3" block in ../main.tf
# points at the bucket/table created here.

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  description = "Region for the state backend resources."
  type        = string
  default     = "eu-west-1"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "DocLens"
      ManagedBy = "terraform-bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "state" {
  bucket = "doclens-terraform-state-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = "doclens-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "lock_table" {
  value = aws_dynamodb_table.locks.name
}
