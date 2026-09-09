# Aurora PostgreSQL Serverless v2 — single engine for operational data and,
# via the pgvector extension, the Bedrock Knowledge Base vector store. See
# ADR-008. Reached over the RDS Data API (enable_http_endpoint) rather than
# direct VPC networking, so neither the API Lambda nor Bedrock KB need to sit
# inside the VPC — see modules/network for the (NAT-less) subnet group.
#
# NOTE: check `aws rds describe-db-engine-versions --engine aurora-postgresql`
# for the current pgvector-capable version before applying; engine_version is
# a variable specifically so this can be bumped without touching this file.
#
# NOTE: `CREATE EXTENSION IF NOT EXISTS vector;` and the `kb` schema (ADR-008)
# must be run once against the cluster via the Data API — not a Terraform
# resource. Track this as a one-time migration step, not part of `apply`.

resource "aws_rds_cluster" "aurora" {
  cluster_identifier = "doclens-${var.environment}"

  engine         = "aurora-postgresql"
  engine_mode    = "provisioned"
  engine_version = var.engine_version

  database_name               = "doclens"
  master_username             = "doclens_admin"
  manage_master_user_password = true
  enable_http_endpoint        = true # RDS Data API
  db_subnet_group_name        = var.db_subnet_group_name
  vpc_security_group_ids      = [var.security_group_id]
  storage_encrypted           = true
  deletion_protection         = var.environment == "prod"
  skip_final_snapshot         = var.environment != "prod"
  final_snapshot_identifier   = var.environment == "prod" ? "doclens-${var.environment}-final" : null
  backup_retention_period     = var.environment == "prod" ? 7 : 1
  preferred_backup_window     = "03:00-04:00"
  apply_immediately           = var.environment != "prod"

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
}

resource "aws_rds_cluster_instance" "aurora" {
  identifier         = "doclens-${var.environment}-1"
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version
}
