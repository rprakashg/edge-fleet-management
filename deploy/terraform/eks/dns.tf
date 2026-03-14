# ──────────────────────────────────────────────────────────
# Route53 A alias records → controller-managed ALB
#
# The ALB is created by the AWS Load Balancer Controller when
# the Ingress (deploy/flightctl/ingress.yml) is applied.
# The controller tags the ALB with ingress.k8s.aws/stack=<group.name>.
# Apply the Ingress first, then run terraform apply to update DNS.
# ──────────────────────────────────────────────────────────

data "aws_route53_zone" "selected_zone" {
  name = var.domain_name
}

data "aws_lb" "ingress" {
  tags = {
    "ingress.k8s.aws/stack" = "edge-manager-alb"
    "elbv2.k8s.aws/cluster" = var.cluster_name
  }
}

resource "aws_route53_record" "flightctl" {
  name    = "flightctl"
  zone_id = data.aws_route53_zone.selected_zone.zone_id
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "service" {
  for_each = local.services_map

  zone_id = data.aws_route53_zone.selected_zone.zone_id

  name = each.value.host
  type = "A"

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
  depends_on = [
    aws_route53_record.flightctl
  ]
}
