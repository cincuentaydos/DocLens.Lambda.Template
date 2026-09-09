# AWS-native edge protection (ADR-009) — replaces the Cloudflare option
# considered in the early architecture sketch. Common rule set + a basic
# rate limit; expand with more AWS Managed Rule groups as real traffic
# patterns emerge (see ADR-009's open questions).

resource "aws_wafv2_web_acl" "cloudfront" {
  provider = aws.us_east_1
  name     = "doclens-cloudfront-${var.environment}"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "doclens-common-rules-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000 # requests per 5-minute window per IP
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "doclens-rate-limit-${var.environment}"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "doclens-cloudfront-waf-${var.environment}"
    sampled_requests_enabled   = true
  }
}
