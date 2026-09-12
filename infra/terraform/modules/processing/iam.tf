# Shared statements every Lambda needs to reach Aurora via the RDS Data API
# (ADR-008) — no VPC networking required.
locals {
  # var.chat_model_id is a cross-region inference profile ID (e.g.
  # "eu.anthropic.claude-haiku-4-5-20251001-v1:0") — some newer Bedrock
  # models don't support direct on-demand invocation by bare foundation
  # model ID at all ("The provided model identifier is invalid"). Invoking
  # through the profile needs bedrock:InvokeModel on BOTH the profile ARN
  # and the underlying foundation model ARN it routes to, so this strips
  # the leading "eu."/"us."/"global." routing prefix to get the latter.
  chat_model_foundation_id = replace(var.chat_model_id, "/^[a-z]+\\./", "")

  aurora_data_api_statements = [
    {
      Sid    = "AuroraDataApi"
      Effect = "Allow"
      Action = [
        "rds-data:ExecuteStatement",
        "rds-data:BatchExecuteStatement",
        "rds-data:BeginTransaction",
        "rds-data:CommitTransaction",
        "rds-data:RollbackTransaction"
      ]
      Resource = var.aurora_cluster_arn
    },
    {
      Sid      = "AuroraSecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.aurora_secret_arn
    },
    {
      # Covers both the Aurora secret above and reading document-bucket
      # objects below — both are encrypted under the same CMK (DocLens.Infra's
      # modules/kms), so one kms:Decrypt statement serves every role here.
      Sid      = "KmsDecrypt"
      Effect   = "Allow"
      Action   = ["kms:Decrypt"]
      Resource = var.kms_key_arn
    }
  ]
}

# --- API Lambda role ---

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/doclens-api-${var.environment}"
  retention_in_days = 30
}

resource "aws_iam_role" "api" {
  name = "doclens-api-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "api" {
  name = "doclens-api-policy-${var.environment}"
  role = aws_iam_role.api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.aurora_data_api_statements, [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.api.arn}:*"
      },
      {
        # POST /documents/prepare only generates the presigned URL — never
        # reads/writes the object body itself (ADR-005).
        Sid      = "S3PresignUpload"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.document_bucket_arn}/*"
      },
      {
        # The presigned URL is signed with this role's credentials, so this
        # role (not the browser that eventually PUTs the object) is who
        # needs kms:GenerateDataKey for the bucket's default SSE-KMS to apply.
        Sid      = "S3PresignUploadKms"
        Effect   = "Allow"
        Action   = ["kms:GenerateDataKey"]
        Resource = var.kms_key_arn
      },
      {
        # /documents/process currently runs OCR synchronously from the API
        # Lambda (the endpoint calls TextractOcrService directly) rather
        # than through the async ADR-006/011 pipeline — that's the
        # scaffold's current shape, not yet the documented target
        # architecture. Mirrors the processor role's S3Read/Textract
        # statements below until this endpoint moves to the queue.
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.document_bucket_arn}/*"
      },
      {
        Sid    = "Textract"
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*"
      },
      {
        Sid    = "BedrockGenerate"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/${local.chat_model_foundation_id}",
          "arn:aws:bedrock:*:*:inference-profile/${var.chat_model_id}"
        ]
      },
      {
        Sid      = "BedrockRetrieve"
        Effect   = "Allow"
        Action   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
        Resource = "*" # scoped down once the Knowledge Base ARN exists — see modules/knowledge_base
      },
      {
        Sid      = "XRay"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ])
  })
}

# --- Processor Lambda role (SQS consumer, ADR-011) ---

resource "aws_cloudwatch_log_group" "processor" {
  name              = "/aws/lambda/doclens-processor-${var.environment}"
  retention_in_days = 30
}

resource "aws_iam_role" "processor" {
  name = "doclens-processor-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "processor" {
  name = "doclens-processor-policy-${var.environment}"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.aurora_data_api_statements, [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.processor.arn}:*"
      },
      {
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.document_bucket_arn}/*"
      },
      {
        Sid    = "Sqs"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.processing.arn
      },
      {
        Sid    = "Textract"
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*"
      },
      {
        Sid      = "TextractPassRole"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.textract_sns_publish.arn
      },
      {
        Sid    = "BedrockExtract"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/${local.chat_model_foundation_id}",
          "arn:aws:bedrock:*:*:inference-profile/${var.chat_model_id}"
        ]
      },
      {
        Sid      = "XRay"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      }
    ])
  })
}

# --- OCR result Lambda role (Textract async completion, ADR-003) ---

resource "aws_cloudwatch_log_group" "ocr_result" {
  name              = "/aws/lambda/doclens-ocr-result-${var.environment}"
  retention_in_days = 30
}

resource "aws_iam_role" "ocr_result" {
  name = "doclens-ocr-result-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ocr_result" {
  name = "doclens-ocr-result-policy-${var.environment}"
  role = aws_iam_role.ocr_result.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.aurora_data_api_statements, [
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.ocr_result.arn}:*"
      },
      {
        Sid    = "Sqs"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.ocr_result.arn
      },
      {
        Sid      = "TextractGetResult"
        Effect   = "Allow"
        Action   = ["textract:GetDocumentTextDetection"]
        Resource = "*"
      }
    ])
  })
}
