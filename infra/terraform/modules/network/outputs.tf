output "vpc_id" {
  value = aws_vpc.main.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.aurora.name
}

output "aurora_security_group_id" {
  value = aws_security_group.aurora.id
}
