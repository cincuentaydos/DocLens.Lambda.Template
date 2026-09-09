output "api_endpoint" {
  description = "Raw HTTP API invoke URL. Consumed by DocLens.Infra's edge module (CloudFront custom origin) via terraform_remote_state — see that repo's README.md \"Cross-repo wiring\"."
  value       = module.processing.api_endpoint
}

output "api_id" {
  value = module.processing.api_id
}

output "processing_queue_arn" {
  description = "Useful for inspecting the DLQ (doclens-processing-dlq-<env>) during troubleshooting."
  value       = module.processing.processing_queue_arn
}
