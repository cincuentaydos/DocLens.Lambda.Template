# Single Cognito User Pool shared by all tenants (empresas). Tenant isolation
# is enforced via the custom:tenantId claim, not separate pools — see
# docs/tenant-onboarding.md. custom:tipoUsuario and custom:clienteId encode
# the user-type model from architecture.md (interno_admin | interno | cliente).

resource "aws_cognito_user_pool" "main" {
  name = "doclens-users-${var.environment}"

  schema {
    name                = "tenantId"
    attribute_data_type = "String"
    mutable             = false
    required            = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "tipoUsuario"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = 1
      max_length = 32
    }
  }

  schema {
    name                = "clienteId"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "doclens-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = var.environment == "prod" ? [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
    ] : [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
  generate_secret               = false

  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    id_token      = "hours"
    refresh_token = "days"
  }
}
