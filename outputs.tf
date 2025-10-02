# =============================================================================
# TERRAFORM OUTPUTS
# =============================================================================
# These outputs provide important information about deployed resources
# Use: terraform output <output_name> to get specific values

# =============================================================================
# EKS CLUSTER INFORMATION
# =============================================================================

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane - used by kubectl and applications"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "OpenID Connect identity provider URL for service account authentication"
  value       = module.eks.cluster_oidc_issuer_url
}

# =============================================================================
# NETWORKING INFORMATION
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC where all resources are deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs (used by EKS nodes and RDS)"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs (used by ALB and NAT gateways)"
  value       = module.vpc.public_subnets
}

# =============================================================================
# APPLICATION RESOURCES
# =============================================================================

output "ecr_repository_url" {
  description = "URL of the ECR repository for pushing Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "load_balancer_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = aws_lb.main.zone_id
}

# =============================================================================
# DATABASE INFORMATION
# =============================================================================

output "rds_endpoint" {
  description = "RDS PostgreSQL instance endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true  # Mark as sensitive to avoid displaying in logs
}

output "rds_port" {
  description = "Port number for RDS PostgreSQL connection"
  value       = aws_db_instance.main.port
}

# =============================================================================
# API GATEWAY INFORMATION
# =============================================================================

output "api_gateway_url" {
  description = "Base URL for API Gateway REST API"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_custom_domain" {
  description = "Custom domain name for API Gateway"
  value       = "https://${aws_api_gateway_domain_name.main.domain_name}"
}

output "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_key" {
  description = "API key for accessing the API Gateway (keep secure)"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

# =============================================================================
# SECURITY INFORMATION
# =============================================================================

output "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  value       = aws_acm_certificate.main.arn
}

output "api_certificate_arn" {
  description = "ARN of the ACM certificate for API Gateway custom domain"
  value       = aws_acm_certificate.api.arn
}

# =============================================================================
# USEFUL COMMANDS
# =============================================================================

output "kubectl_config" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_login" {
  description = "Command to login to ECR for Docker push"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}"
}

# =============================================================================
# MONITORING ENDPOINTS
# =============================================================================

output "grafana_access" {
  description = "Command to access Grafana dashboard"
  value       = "kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
}

output "application_health_check" {
  description = "URL for application health check"
  value       = "https://${aws_lb.main.dns_name}/health"
}

# =============================================================================
# DEPLOYMENT SUMMARY
# =============================================================================

output "deployment_summary" {
  description = "Summary of deployed resources and access information"
  value = {
    cluster_name     = module.eks.cluster_name
    api_gateway_url  = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
    custom_api_url   = "https://${aws_api_gateway_domain_name.main.domain_name}"
    application_url  = "https://${aws_lb.main.dns_name}"
    ecr_repository   = aws_ecr_repository.app.repository_url
    region          = var.aws_region
    environment     = var.environment
  }
}
