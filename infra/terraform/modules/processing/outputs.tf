output "api_endpoint" {
  value = aws_apigatewayv2_stage.default.invoke_url
}

output "api_id" {
  value = aws_apigatewayv2_api.main.id
}

output "api_lambda_arn" {
  value = aws_lambda_function.api.arn
}

output "api_lambda_role_arn" {
  value = aws_iam_role.api.arn
}

output "processor_lambda_arn" {
  value = aws_lambda_function.processor.arn
}

output "ocr_result_lambda_arn" {
  value = aws_lambda_function.ocr_result.arn
}

output "artifacts_bucket_arn" {
  value = aws_s3_bucket.artifacts.arn
}

output "processing_queue_arn" {
  value = aws_sqs_queue.processing.arn
}
