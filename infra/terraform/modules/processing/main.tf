resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/doclens-processor-${var.environment}"
  retention_in_days = 30
}

resource "aws_iam_role" "lambda" {
  name = "doclens-processor-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# CDK grants this automatically via grantRead / grantReadWriteData — in Terraform it's explicit
resource "aws_iam_role_policy" "lambda_permissions" {
  name = "doclens-processor-policy-${var.environment}"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      },
      {
        Sid      = "S3Read"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "${var.document_bucket_arn}/*"
      },
      {
        Sid    = "DynamoDB"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = var.jobs_table_arn
      },
      {
        Sid    = "Textract"
        Effect = "Allow"
        Action = [
          "textract:DetectDocumentText",
          "textract:StartDocumentTextDetection",
          "textract:GetDocumentTextDetection"
        ]
        Resource = "*"
      },
      {
        Sid      = "Bedrock"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-haiku*"
      },
      {
        Sid    = "XRay"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "processor" {
  function_name = "doclens-processor-${var.environment}"
  role          = aws_iam_role.lambda.arn
  handler = "DocLens.Lambda"

  # provider lag: hashicorp/aws ~5.x does not yet list "dotnet10" as a valid runtime.
  # Using provided.al2023 (custom runtime) until the provider is updated.
  # CDK does not have this problem — it passes the value directly to CloudFormation.
  # See: docs/adr-002-iac-strategy.md — "Provider lag for new AWS services"
  runtime = "provided.al2023"
  filename      = var.lambda_zip_path
  memory_size   = 512
  timeout       = 30

  # source_code_hash ensures Terraform redeploys when the ZIP changes
  source_code_hash = filebase64sha256(var.lambda_zip_path)

  tracing_config {
    mode = "Active"
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda.name
    log_format = "JSON"
  }

  environment {
    variables = {
      DOCUMENT_BUCKET = var.document_bucket_id
      JOBS_TABLE      = var.jobs_table_name
    }
  }

  depends_on = [aws_iam_role_policy.lambda_permissions]
}

resource "aws_apigatewayv2_api" "main" {
  name          = "doclens-api-${var.environment}"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["Authorization", "Content-Type"]
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"

  jwt_configuration {
    audience = ["doclens-web-client"]
    issuer   = var.user_pool_endpoint
  }
}

resource "aws_apigatewayv2_integration" "processor" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.processor.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "process_document" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /documents/process"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  target             = "integrations/${aws_apigatewayv2_integration.processor.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
