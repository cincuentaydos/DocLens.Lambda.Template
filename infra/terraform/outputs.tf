output "api_endpoint" {
  description = "DocLens API Gateway endpoint."
  value       = module.processing.api_endpoint
}

output "document_bucket_id" {
  description = "S3 bucket name for uploaded documents."
  value       = module.storage.document_bucket_id
}

output "jobs_table_name" {
  description = "DynamoDB table name for processing jobs."
  value       = module.storage.jobs_table_name
}

output "user_pool_id" {
  description = "Cognito User Pool ID."
  value       = module.auth.user_pool_id
}

output "user_pool_client_id" {
  description = "Cognito User Pool client ID for the web application."
  value       = module.auth.user_pool_client_id
}
