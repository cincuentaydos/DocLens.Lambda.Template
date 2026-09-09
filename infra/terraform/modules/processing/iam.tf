# Shared statements every Lambda needs to reach Aurora via the RDS Data API
# (ADR-008) — no VPC networking required.
locals {
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
        Sid      = "BedrockGenerate"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/${var.chat_model_id}"
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
        Sid      = "BedrockExtract"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/${var.chat_model_id}"
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
