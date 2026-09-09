variable "environment" {
  type = string
}

variable "frontend_origins" {
  description = "Allowed CORS origins for direct browser PUT uploads (ADR-005)."
  type        = list(string)
}
