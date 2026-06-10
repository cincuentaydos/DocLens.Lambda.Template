output "document_bucket_arn" {
  value = aws_s3_bucket.documents.arn
}

output "document_bucket_id" {
  value = aws_s3_bucket.documents.id
}

output "jobs_table_arn" {
  value = aws_dynamodb_table.jobs.arn
}

output "jobs_table_name" {
  value = aws_dynamodb_table.jobs.name
}
