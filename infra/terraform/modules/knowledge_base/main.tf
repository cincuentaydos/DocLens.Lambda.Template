# Bedrock Knowledge Base backed by Aurora PostgreSQL + pgvector (ADR-001,
# ADR-008) instead of the OpenSearch Serverless default.
#
# BEST-EFFORT MODULE — verify before relying on it:
#   1. `aws_bedrockagent_knowledge_base` / `aws_bedrockagent_data_source`
#      support for RDS-backed (as opposed to OpenSearch Serverless) storage
#      configurations may lag in the pinned hashicorp/aws ~> 5.x provider —
#      this is exactly the provider-lag risk flagged in ADR-002. Run
#      `terraform providers schema -json | grep -A30 bedrockagent_knowledge_base`
#      against the resolved provider version before applying.
#   2. The target table (`kb.embeddings`, per ADR-008) and the
#      `CREATE EXTENSION vector;` statement must already exist in Aurora —
#      that's a one-time Data API migration, not a Terraform resource here.
#   3. If the RDS storage type isn't available yet in the resolved provider
#      version, comment this module's instantiation out of the root main.tf
#      rather than blocking the rest of the stack — nothing else depends on
#      knowledge_base's outputs.

resource "aws_iam_role" "kb" {
  name = "doclens-kb-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "kb" {
  name = "doclens-kb-policy-${var.environment}"
  role = aws_iam_role.kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.document_bucket_arn, "${var.document_bucket_arn}/*"]
      },
      {
        Sid      = "Embed"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/${var.embedding_model_id}"
      },
      {
        Sid    = "AuroraDataApi"
        Effect = "Allow"
        Action = [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement"
        ]
        Resource = var.aurora_cluster_arn
      },
      {
        Sid      = "AuroraSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      }
    ]
  })
}

resource "aws_bedrockagent_knowledge_base" "documents" {
  name     = "doclens-documents-${var.environment}"
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:eu-west-1::foundation-model/${var.embedding_model_id}"
    }
  }

  storage_configuration {
    type = "RDS"

    rds_configuration {
      credentials_secret_arn = var.aurora_secret_arn
      database_name          = var.database_name
      resource_arn           = var.aurora_cluster_arn
      table_name             = "kb.embeddings"

      field_mapping {
        primary_key_field = "id"
        vector_field      = "embedding"
        text_field        = "chunk_texto"
        metadata_field    = "metadata"
      }
    }
  }

  depends_on = [aws_iam_role_policy.kb]
}

resource "aws_bedrockagent_data_source" "documents" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.documents.id
  name              = "doclens-documents-source-${var.environment}"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = var.document_bucket_arn
    }
  }
}
