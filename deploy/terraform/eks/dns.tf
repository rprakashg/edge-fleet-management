# ──────────────────────────────────────────────────────────
# Route53 A alias records → shared ALB
#
# Because the ALB is pre-created by Terraform (not by the
# LB controller), its DNS name is known immediately and no
# timing workarounds are needed.
# ──────────────────────────────────────────────────────────

data "aws_route53_zone" "selected_zone" {
  name = var.domain_name
}

resource "aws_route53_record" "flightctl" {
  name = "flightctl"
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  type    = "A"

  alias {
    name                   = aws_lb.shared.dns_name
    zone_id                = aws_lb.shared.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "service" {
  for_each = local.services_map

  zone_id = data.aws_route53_zone.selected_zone.zone_id
  
  name    = each.value.host
  type    = "A"

  alias {
    name                   = aws_lb.shared.dns_name
    zone_id                = aws_lb.shared.zone_id
    evaluate_target_health = true
  }
  depends_on = [ 
    aws_route53_record.flightctl 
  ]
}
