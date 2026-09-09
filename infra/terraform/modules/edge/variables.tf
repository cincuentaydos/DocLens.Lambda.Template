variable "environment" {
  type = string
}

variable "domain_name" {
  description = "Root domain the user registers themselves (e.g. \"doclens-example.com\"). Not managed by Terraform — domain purchase is a manual, billable step."
  type        = string
}

variable "create_hosted_zone" {
  description = "true: Terraform creates the Route 53 hosted zone. false: read an existing zone instead (e.g. one AWS auto-created because the domain was registered directly through Route 53's registrar)."
  type        = bool
  default     = true
}

variable "api_endpoint" {
  description = "Invoke URL of the HTTP API (modules.processing.api_endpoint) — used as a CloudFront custom origin."
  type        = string
}
