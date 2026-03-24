# ──────────────────────────────────────────────────────────
# ALB is managed by the AWS Load Balancer Controller via
# the Kubernetes Ingress resource in deploy/flightctl/ingress.yml.
# Route53 records (dns.tf) look up the controller-created ALB
# by its ingress.k8s.aws/stack tag.
# ──────────────────────────────────────────────────────────

locals {
  services_map = { for s in var.services : s.name => s }
}
