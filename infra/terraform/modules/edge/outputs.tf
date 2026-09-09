output "site_url" {
  value = "https://${local.fqdn}"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "frontend_bucket_id" {
  value = aws_s3_bucket.frontend.id
}

output "zone_id" {
  value = local.zone_id
}

output "name_servers" {
  description = "If create_hosted_zone=true, point your registrar (or Route 53 domain registration) at these NS records."
  value       = var.create_hosted_zone ? aws_route53_zone.main[0].name_servers : null
}
