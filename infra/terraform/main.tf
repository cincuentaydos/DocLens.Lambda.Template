terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend values are intentionally omitted here and passed at init time so
  # sbx and prod can share one state bucket/lock table (created by
  # bootstrap/) under different keys:
  #
  #   terraform init \
  #     -backend-config="bucket=doclens-terraform-state-<ACCOUNT_ID>" \
  #     -backend-config="key=infra/<ENV>/terraform.tfstate" \
  #     -backend-config="region=eu-west-1" \
  #     -backend-config="dynamodb_table=doclens-terraform-locks" \
  #     -backend-config="encrypt=true"
  #
  # <ACCOUNT_ID> and the bucket name come from `terraform output` in
  # bootstrap/ (run once, see bootstrap/main.tf). <ENV> is "sbx" or "prod".
  backend "s3" {}
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

# ACM certificates and the CloudFront WAF WebACL must live in us-east-1
# regardless of the primary region — see ADR-009.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "DocLens"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  site_fqdn = var.environment == "prod" ? var.domain_name : "${var.environment}.${var.domain_name}"
}

module "network" {
  source      = "./modules/network"
  environment = var.environment
}

module "auth" {
  source      = "./modules/auth"
  environment = var.environment
}

module "data" {
  source               = "./modules/data"
  environment          = var.environment
  db_subnet_group_name = module.network.db_subnet_group_name
  security_group_id    = module.network.aurora_security_group_id
}

module "documents" {
  source           = "./modules/documents"
  environment      = var.environment
  frontend_origins = ["https://${local.site_fqdn}"]
}

module "processing" {
  source              = "./modules/processing"
  environment         = var.environment
  document_bucket_arn = module.documents.bucket_arn
  document_bucket_id  = module.documents.bucket_id
  aurora_cluster_arn  = module.data.cluster_arn
  aurora_secret_arn   = module.data.master_user_secret_arn
  user_pool_client_id = module.auth.user_pool_client_id
  user_pool_endpoint  = module.auth.user_pool_endpoint
  lambda_zip_path     = var.lambda_zip_path
  embedding_model_id  = var.embedding_model_id
  chat_model_id       = var.chat_model_id
}

module "knowledge_base" {
  source              = "./modules/knowledge_base"
  environment         = var.environment
  document_bucket_arn = module.documents.bucket_arn
  aurora_cluster_arn  = module.data.cluster_arn
  aurora_secret_arn   = module.data.master_user_secret_arn
  database_name       = module.data.database_name
  embedding_model_id  = var.embedding_model_id
}

module "edge" {
  source = "./modules/edge"
  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }
  environment        = var.environment
  domain_name        = var.domain_name
  create_hosted_zone = var.create_hosted_zone
  api_endpoint       = module.processing.api_endpoint
}
