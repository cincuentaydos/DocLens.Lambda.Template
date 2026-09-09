# Main processing queue — decouples the GuardDuty-clean event from the
# Processor Lambda (ADR-011). Visibility timeout must exceed the Processor
# Lambda's timeout (5 min, see lambdas.tf) so a slow OCR job never causes a
# duplicate delivery.

resource "aws_sqs_queue" "processing_dlq" {
  name                      = "doclens-processing-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 days
}

resource "aws_sqs_queue" "processing" {
  name                       = "doclens-processing-${var.environment}"
  visibility_timeout_seconds = 360

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.processing_dlq.arn
    maxReceiveCount     = 3
  })
}

# --- Textract async OCR completion (ADR-003 / architecture.md) ---
# For multi-page scanned documents the Processor Lambda calls
# StartDocumentTextDetection and returns; Textract publishes completion to
# this SNS topic, which fans out to the SQS queue the OCR result Lambda
# consumes (see lambdas.tf).

resource "aws_sns_topic" "textract_completion" {
  name = "doclens-textract-completion-${var.environment}"
}

resource "aws_sqs_queue" "ocr_result_dlq" {
  name                      = "doclens-ocr-result-dlq-${var.environment}"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "ocr_result" {
  name                       = "doclens-ocr-result-${var.environment}"
  visibility_timeout_seconds = 120

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.ocr_result_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "ocr_result_allow_sns" {
  queue_url = aws_sqs_queue.ocr_result.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSNS"
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.ocr_result.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_sns_topic.textract_completion.arn } }
    }]
  })
}

resource "aws_sns_topic_subscription" "ocr_result" {
  topic_arn = aws_sns_topic.textract_completion.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.ocr_result.arn
}

# Role Textract assumes to publish the completion notification.
resource "aws_iam_role" "textract_sns_publish" {
  name = "doclens-textract-sns-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "textract.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "textract_sns_publish" {
  name = "doclens-textract-sns-${var.environment}"
  role = aws_iam_role.textract_sns_publish.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "Publish"
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.textract_completion.arn
    }]
  })
}
