output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "user_pool_endpoint" {
  value = "https://${aws_cognito_user_pool.main.endpoint}"
}
