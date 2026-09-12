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

variable "lambda_zip_path" {
  description = <<-EOT
    Path to the Lambda deployment ZIP shared by the API, Processor, and OCR
    result functions (see modules/processing).
    Build with: dotnet publish ../../src/DocLens.Lambda -c Release -o /tmp/lambda-out
    then: zip -j /tmp/lambda-out/doclens-lambda.zip /tmp/lambda-out/*
  EOT
  type        = string
  default     = "../../src/DocLens.Lambda/bin/Release/net10.0/linux-x64/publish/doclens-lambda.zip"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model (ADR-001). Must match the value DocLens.Infra's knowledge_base module uses — see that repo's README.md \"Cross-repo wiring\"."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "chat_model_id" {
  description = "Bedrock Claude model used for semantic extraction, chat and drafting."
  type        = string
  default     = "eu.anthropic.claude-haiku-4-5-20251001-v1:0"
}
