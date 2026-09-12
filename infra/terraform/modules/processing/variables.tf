variable "environment" {
  type = string
}

variable "document_bucket_arn" {
  type = string
}

variable "document_bucket_id" {
  type = string
}

variable "aurora_cluster_arn" {
  type = string
}

variable "aurora_secret_arn" {
  description = "Secrets Manager ARN for the Aurora managed master credentials — needed by both Lambdas to call the RDS Data API."
  type        = string
}

variable "user_pool_client_id" {
  type = string
}

variable "user_pool_endpoint" {
  type = string
}

variable "kms_key_arn" {
  description = "CMK the document bucket and the Aurora master secret are encrypted with (DocLens.Infra's modules/kms) — needed for S3/Secrets Manager access under that key."
  type        = string
}

variable "lambda_zip_path" {
  description = <<-EOT
    Path to the single Lambda deployment ZIP shared by all three functions
    below (API, Processor, OCR result) — each just points at a different
    handler inside the same published .NET assembly.
    Build with: dotnet publish src/DocLens.Lambda -c Release -o /tmp/lambda-out
    then: zip -j /tmp/doclens-lambda.zip /tmp/lambda-out/*
  EOT
  type        = string
}

variable "api_handler" {
  description = "Lambda handler string for the API Lambda (ASP.NET Core minimal API host, all Procesos/Clientes/Documentos/Usuarios/IA routes — see projects/lambda.md)."
  type        = string
  default     = "DocLens.Lambda::DocLens.Lambda.LambdaEntryPoint::FunctionHandlerAsync"
}

variable "processor_handler" {
  description = "Lambda handler string for the Processor Lambda (SQS consumer — OCR + semantic extraction, see ADR-011)."
  type        = string
  default     = "DocLens.Lambda::DocLens.Lambda.ProcessorHandler::HandleAsync"
}

variable "ocr_result_handler" {
  description = "Lambda handler string for the OCR async result Lambda (Textract StartDocumentTextDetection completion via SNS/SQS — see ADR-003)."
  type        = string
  default     = "DocLens.Lambda::DocLens.Lambda.OcrResultHandler::HandleAsync"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model used for RAG (ADR-001)."
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "chat_model_id" {
  description = "Bedrock Claude model used for semantic extraction, chat and drafting."
  type        = string
  default     = "anthropic.claude-3-5-sonnet-20241022-v2:0"
}
