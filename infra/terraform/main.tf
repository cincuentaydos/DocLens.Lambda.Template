terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment to enable remote state (recommended for team use)
  # backend "s3" {
  #   bucket         = "doclens-terraform-state"
  #   key            = "infra/terraform.tfstate"
  #   region         = "eu-west-1"
  #   dynamodb_table = "doclens-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "DocLens"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "storage" {
  source      = "./modules/storage"
  environment = var.environment
}

module "auth" {
  source      = "./modules/auth"
  environment = var.environment
}

module "processing" {
  source              = "./modules/processing"
  environment         = var.environment
  document_bucket_arn = module.storage.document_bucket_arn
  document_bucket_id  = module.storage.document_bucket_id
  jobs_table_arn      = module.storage.jobs_table_arn
  jobs_table_name     = module.storage.jobs_table_name
  user_pool_endpoint  = module.auth.user_pool_endpoint
  lambda_zip_path     = var.lambda_zip_path
}
