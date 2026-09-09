variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["sbx", "prod"], var.environment)
    error_message = "environment must be sbx or prod."
  }
}

variable "domain_name" {
  description = "Root domain you registered yourself (e.g. \"doclens-example.com\"). prod uses it bare; sbx (and any future env) gets \"<environment>.<domain_name>\". Domain purchase is manual — Terraform only manages the hosted zone and everything downstream (ADR-009)."
  type        = string
}

variable "create_hosted_zone" {
  description = "true: Terraform creates the Route 53 hosted zone. Set to false and Terraform will read an existing zone instead if you registered the domain directly through Route 53's registrar (which auto-creates its own zone)."
  type        = bool
  default     = true
}

variable "lambda_zip_path" {
  description = <<-EOT
    Path to the Lambda deployment ZIP shared by the API, Processor, and OCR
    result functions (see modules/processing).
    Build with: dotnet publish src/DocLens.Lambda -c Release -o /tmp/lambda-out
    then: zip -j /tmp/doclens-lambda.zip /tmp/lambda-out/*
  EOT
  type        = string
  default     = "../../src/DocLens.Lambda/bin/Release/net10.0/linux-x64/publish/doclens-lambda.zip"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model for the Knowledge Base (ADR-001)."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "chat_model_id" {
  description = "Bedrock Claude model for semantic extraction, chat and drafting."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
