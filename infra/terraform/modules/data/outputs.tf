output "cluster_arn" {
  value = aws_rds_cluster.aurora.arn
}

output "cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "database_name" {
  value = aws_rds_cluster.aurora.database_name
}

output "master_user_secret_arn" {
  description = "Secrets Manager ARN for the AWS-managed master credentials (manage_master_user_password)."
  value       = aws_rds_cluster.aurora.master_user_secret[0].secret_arn
}
