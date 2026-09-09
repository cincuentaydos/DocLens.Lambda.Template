# ACM certificates and WAF WebACLs used by CloudFront must exist in
# us-east-1 regardless of the stack's primary region (AWS constraint) — see
# ADR-009. The root module passes both the default and aliased provider in.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
