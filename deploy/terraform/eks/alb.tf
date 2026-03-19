# ──────────────────────────────────────────────────────────
# ALB is managed by the AWS Load Balancer Controller via
# the Kubernetes Ingress resource in deploy/flightctl/ingress.yml.
# Route53 records (dns.tf) look up the controller-created ALB
# by its ingress.k8s.aws/stack tag.
# ──────────────────────────────────────────────────────────

locals {
  services_map = { for s in var.services : s.name => s }
}

# ──────────────────────────────────────────────────────────
# mTLS Trust Store
# Used by the agent-api Ingress annotation:
#   alb.ingress.kubernetes.io/mutual-authentication
#
# Set mtls_ca_bundle_path to a local PEM file containing the
# CA cert(s) that signed your device client certificates.
# After terraform apply, update ingress.yml with the output:
#   terraform output trust_store_arn
# ──────────────────────────────────────────────────────────

resource "aws_s3_bucket" "mtls_trust_store" {
  count  = var.mtls_ca_bundle_path != null ? 1 : 0
  bucket = "${var.cluster_name}-mtls-trust-store"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "mtls_trust_store" {
  count  = var.mtls_ca_bundle_path != null ? 1 : 0
  bucket = aws_s3_bucket.mtls_trust_store[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_object" "ca_bundle" {
  count   = var.mtls_ca_bundle_path != null ? 1 : 0
  bucket  = aws_s3_bucket.mtls_trust_store[0].id
  key     = "ca-bundle.pem"
  content = file(var.mtls_ca_bundle_path)
}

resource "aws_lb_trust_store" "mtls" {
  count                            = var.mtls_ca_bundle_path != null ? 1 : 0
  name                             = "${var.cluster_name}-mtls"
  ca_certificates_bundle_s3_bucket = aws_s3_bucket.mtls_trust_store[0].id
  ca_certificates_bundle_s3_key    = aws_s3_object.ca_bundle[0].key
  tags                             = var.tags

  depends_on = [aws_s3_object.ca_bundle]
}
