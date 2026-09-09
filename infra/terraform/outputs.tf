output "site_url" {
  value = module.edge.site_url
}

output "name_servers" {
  description = "Point your domain registrar at these (or skip this if create_hosted_zone=false)."
  value       = module.edge.name_servers
}

output "api_endpoint" {
  description = "Raw HTTP API invoke URL (also reachable via site_url/api once DNS propagates)."
  value       = module.processing.api_endpoint
}

output "document_bucket_id" {
  value = module.documents.bucket_id
}

output "user_pool_id" {
  value = module.auth.user_pool_id
}

output "user_pool_client_id" {
  value = module.auth.user_pool_client_id
}

output "aurora_cluster_endpoint" {
  value = module.data.cluster_endpoint
}

output "aurora_secret_arn" {
  description = "Secrets Manager ARN holding the Aurora master credentials — use this to run the one-time `CREATE EXTENSION vector;` / kb schema migration via the RDS Data API (see ADR-008)."
  value       = module.data.master_user_secret_arn
}

output "knowledge_base_id" {
  value = module.knowledge_base.knowledge_base_id
}
