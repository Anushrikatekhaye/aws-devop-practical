output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "HTTPS URL of the application."
  value       = local.use_domain ? "https://${var.domain_name}" : "https://${aws_lb.main.dns_name}"
}

output "acm_validation_records" {
  description = "DNS records to create at your DNS provider when domain_name is set without a Route 53 zone."
  value = local.use_domain ? {
    for dvo in aws_acm_certificate.domain[0].domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "app_bucket" {
  value = aws_s3_bucket.app.id
}

output "alb_logs_bucket" {
  value = aws_s3_bucket.alb_logs.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}
