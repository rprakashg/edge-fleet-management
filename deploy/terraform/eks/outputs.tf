output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN of the EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_group_iam_role_arn" {
  description = "IAM role ARN of the managed node group"
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN (wildcard for *.domain_name)"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "alb_arn" {
  description = "ARN of the shared ALB"
  value       = aws_lb.shared.arn
}

output "alb_dns_name" {
  description = "DNS name of the shared ALB"
  value       = aws_lb.shared.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the shared ALB (for Route53 alias records)"
  value       = aws_lb.shared.zone_id
}

output "service_urls" {
  description = "HTTPS URLs for each exposed service"
  value       = { for k, s in local.services_map : k => "https://${s.host}" }
}

output "hosted_zone" {
  description = "Route 53 hosted zone"
  value       = data.aws_route53_zone.selected_zone.zone_id
}
