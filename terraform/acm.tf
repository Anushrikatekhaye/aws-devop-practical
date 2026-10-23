locals {
  use_domain = var.domain_name != ""
  use_zone   = local.use_domain && var.route53_zone_id != ""
}

# ------------------------------------------------------------------
# Option A: real domain -> ACM-issued, DNS-validated certificate.
# ------------------------------------------------------------------
resource "aws_acm_certificate" "domain" {
  count             = local.use_domain ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.use_zone ? {
    for dvo in aws_acm_certificate.domain[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

# Waits until the cert is ISSUED. If the DNS zone is not in Route 53, add the
# CNAME from the `acm_validation_records` output at your DNS provider.
resource "aws_acm_certificate_validation" "domain" {
  count                   = local.use_domain ? 1 : 0
  certificate_arn         = aws_acm_certificate.domain[0].arn
  validation_record_fqdns = local.use_zone ? [for r in aws_route53_record.cert_validation : r.fqdn] : null
}

resource "aws_route53_record" "app" {
  count   = local.use_zone ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# ------------------------------------------------------------------
# Option B: no domain yet -> self-signed cert imported into ACM so the
# HTTPS listener works end to end for the demo (browser warning expected).
# ------------------------------------------------------------------
resource "tls_private_key" "self_signed" {
  count     = local.use_domain ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count           = local.use_domain ? 0 : 1
  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = "${local.name}.internal.example"
    organization = var.project_name
  }

  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "self_signed" {
  count            = local.use_domain ? 0 : 1
  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem
}
