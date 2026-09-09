output "bucket_arn" {
  value = aws_s3_bucket.documents.arn
}

output "bucket_id" {
  value = aws_s3_bucket.documents.id
}

output "malware_protection_plan_id" {
  value = aws_guardduty_malware_protection_plan.documents.id
}
