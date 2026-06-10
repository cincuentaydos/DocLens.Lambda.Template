variable "aws_region" {
  description = "Primary AWS region."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "lambda_zip_path" {
  description = <<-EOT
    Path to the Lambda deployment ZIP file.
    Build with: dotnet publish src/DocLens.Lambda -c Release -o /tmp/lambda-out
    then: zip -j /tmp/doclens-lambda.zip /tmp/lambda-out/*
  EOT
  type        = string
  default     = "../../src/DocLens.Lambda/bin/Release/net10.0/linux-x64/publish/doclens-lambda.zip"
}
