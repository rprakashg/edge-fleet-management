# ──────────────────────────────────────────────────────────
# Pre-created shared Application Load Balancer
#
# The ALB and all associated AWS resources are managed
# entirely by Terraform. A wildcard ACM certificate
# (see acm.tf) is attached to the HTTPS listener for SSL
# termination. No Kubernetes Ingress resources are used.
# ──────────────────────────────────────────────────────────

locals {
  services_map = { for s in var.services : s.name => s }
}

# ── Security Group ────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Allow inbound HTTP/HTTPS to the shared ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-alb-sg"
  })
}

# ── ALB ───────────────────────────────────────────────────

resource "aws_lb" "shared" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-alb"
  })
}

# ── Listeners ─────────────────────────────────────────────

# HTTP (80) → HTTPS (443) permanent redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.shared.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS (443) — host-based rules below handle routing;
# default action returns 404 for unmatched requests.
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.shared.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

# ── Per-service target groups & listener rules ────────────

# Target group names are capped at 32 characters by AWS.
resource "aws_lb_target_group" "service" {
  for_each = local.services_map

  name        = substr("${var.cluster_name}-${each.key}", 0, 32)
  port        = each.value.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    path                = each.value.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  # Allow graceful replacement: create new TG before destroying old one.
  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })
}

# Host-header routing rule — one per service.
# Priority is auto-assigned by AWS when omitted.
resource "aws_lb_listener_rule" "service" {
  for_each = local.services_map

  listener_arn = aws_lb_listener.https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }

  condition {
    host_header {
      values = [each.value.host]
    }
  }
}
