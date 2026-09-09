# GuardDuty scan-result → EventBridge → SQS (ADR-011). Only a CLEAN result
# reaches the processing queue; the rule simply never matches/forwards
# anything else, so a threat or unscannable file never reaches the Processor
# Lambda's extraction logic.
#
# NOTE: the exact event pattern below (source/detail-type/detail field names)
# is a best-effort reconstruction of the GuardDuty Malware Protection for S3
# "object scan result" event — verify it against a real captured event (or
# the current AWS documentation) before relying on it, since this is a
# comparatively new event type and the schema isn't hand-verified here.
#
# The "not clean" path (THREATS_FOUND / UNSCANNABLE → write REJECTED) is an
# open question in ADR-011/ADR-004 and intentionally NOT wired here yet.

resource "aws_cloudwatch_event_rule" "guardduty_clean_scan" {
  name        = "doclens-guardduty-clean-${var.environment}"
  description = "Forwards GuardDuty Malware Protection scan results for the documents bucket to SQS only when the result is clean."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Malware Protection Object Scan Result"]
    detail = {
      s3ObjectDetails = {
        bucketName = [var.document_bucket_id]
      }
      scanResultDetails = {
        scanResultStatus = ["NO_THREATS_FOUND"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_clean_to_sqs" {
  rule = aws_cloudwatch_event_rule.guardduty_clean_scan.name
  arn  = aws_sqs_queue.processing.arn
}

resource "aws_sqs_queue_policy" "processing_allow_eventbridge" {
  queue_url = aws_sqs_queue.processing.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridge"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.processing.arn
      Condition = { ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.guardduty_clean_scan.arn } }
    }]
  })
}
