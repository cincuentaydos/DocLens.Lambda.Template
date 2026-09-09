variable "environment" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version. Must support the pgvector extension (see ADR-008) — verify with `aws rds describe-db-engine-versions --engine aurora-postgresql` before applying."
  type        = string
  default     = "16.6"
}

variable "min_capacity" {
  description = "Minimum Aurora Capacity Units (ACU). 0.5 is the lowest available for Serverless v2."
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum Aurora Capacity Units (ACU)."
  type        = number
  default     = 4
}
