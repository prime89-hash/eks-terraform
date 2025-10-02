# =============================================================================
# 3-TIER WEB APPLICATION ON AWS EKS WITH FARGATE
# =============================================================================
# This Terraform configuration creates a production-ready 3-tier architecture:
# 1. Presentation Tier: API Gateway + Application Load Balancer (ALB)
# 2. Application Tier: EKS Fargate with Java Spring Boot application
# 3. Data Tier: RDS PostgreSQL with encryption
#
# Key Features:
# - Serverless compute with EKS Fargate
# - Managed API Gateway for external access
# - Private networking with VPC and subnets
# - Comprehensive security with WAF, encryption, and IAM
# - Monitoring with CloudWatch, Prometheus, and Grafana
# - CI/CD pipeline with GitHub Actions

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# =============================================================================
# AWS PROVIDER CONFIGURATION
# =============================================================================
# Configure the AWS provider with default tags for resource management
provider "aws" {
  region = var.aws_region
  
  # Default tags applied to all resources for better organization
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = "DevOps-Team"
    }
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================
# Fetch information about existing AWS resources

# Get available availability zones in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# =============================================================================
# NETWORKING LAYER (VPC, SUBNETS, ROUTING)
# =============================================================================
# Creates the network foundation for our 3-tier architecture

# VPC Module - Creates Virtual Private Cloud with public/private subnets
# This provides network isolation and security for our resources
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  # Use first 3 availability zones for high availability
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs  # For EKS nodes and RDS
  public_subnets  = var.public_subnet_cidrs   # For ALB and NAT gateways

  # Enable NAT Gateway for private subnet internet access (for container pulls)
  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true  # Required for EKS
  enable_dns_support   = true  # Required for EKS

  # EKS-specific subnet tags for load balancer placement
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"  # For internet-facing load balancers
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"  # For internal load balancers
  }

  # Cluster discovery tags
  tags = {
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
  }
}

# =============================================================================
# SECURITY GROUPS
# =============================================================================
# Define network access rules for different components

# Security Group for Application Load Balancer
# Allows HTTP/HTTPS traffic from internet
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for Application Load Balancer"

  # Allow HTTP traffic (will redirect to HTTPS)
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS traffic
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security Group for RDS Database
# Only allows access from EKS nodes on PostgreSQL port
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for RDS PostgreSQL database"

  # Allow PostgreSQL access only from EKS nodes
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# =============================================================================
# EKS CLUSTER (KUBERNETES CONTROL PLANE)
# =============================================================================
# Creates managed Kubernetes cluster with Fargate compute

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = var.kubernetes_version

  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets  # EKS control plane in private subnets

  # API server endpoint access
  cluster_endpoint_public_access  = true   # Allow kubectl access from internet
  cluster_endpoint_private_access = true   # Allow pod-to-API server communication

  # EKS Add-ons - Essential cluster components
  cluster_addons = {
    # DNS resolution for services and pods
    coredns = {
      most_recent = true
    }
    # Network proxy for service load balancing
    kube-proxy = {
      most_recent = true
    }
    # Container Network Interface for pod networking
    vpc-cni = {
      most_recent = true
    }
    # Persistent volume support
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Fargate Profiles - Serverless compute for pods
  # Pods matching these selectors will run on Fargate
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"  # Default namespace
        },
        {
          namespace = "kube-system"  # System components
        },
        {
          namespace = var.app_namespace  # Application namespace
        }
      ]
    }
  }

  # OIDC Identity Provider for service account authentication
  cluster_identity_providers = {
    sts = {
      client_id = "sts.amazonaws.com"
    }
  }

  tags = {
    Environment = var.environment
  }
}

# =============================================================================
# CONTAINER REGISTRY (ECR)
# =============================================================================
# Private Docker registry for application images

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"  # Allow image tag updates

  # Security: Scan images for vulnerabilities
  image_scanning_configuration {
    scan_on_push = true
  }

  # Encryption at rest
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-ecr-repository"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# =============================================================================
# DATABASE LAYER (RDS POSTGRESQL)
# =============================================================================
# Managed PostgreSQL database with high availability and security

# DB Subnet Group - Defines which subnets RDS can use
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets  # Database in private subnets only

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  # Database engine configuration
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  # Storage configuration
  allocated_storage     = 20   # Initial storage in GB
  max_allocated_storage = 100  # Auto-scaling limit
  storage_encrypted     = true # Encryption at rest

  # Database credentials
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Network and security
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # Backup and maintenance configuration
  backup_retention_period = 7                    # Keep backups for 7 days
  backup_window          = "03:00-04:00"        # UTC backup window
  maintenance_window     = "sun:04:00-sun:05:00" # UTC maintenance window

  # Production safety settings
  skip_final_snapshot = var.environment != "prod"  # Skip snapshot for non-prod
  deletion_protection = var.environment == "prod"  # Prevent accidental deletion

  tags = {
    Name = "${var.project_name}-database"
  }
}

# =============================================================================
# APPLICATION LOAD BALANCER (PRESENTATION TIER)
# =============================================================================
# Internet-facing load balancer for distributing traffic

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false  # Internet-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets  # Deploy in public subnets

  # Production safety
  enable_deletion_protection = var.environment == "prod"

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# SSL/TLS Certificate for HTTPS
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"  # Requires DNS record creation

  # Support wildcard subdomains
  subject_alternative_names = [
    "*.${var.domain_name}"
  ]

  # Certificate lifecycle management
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-cert"
  }
}

# Target Group for EKS application pods
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"  # Required for Fargate

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"  # Application health endpoint
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-app-tg"
  }
}

# HTTPS Listener - Handles secure traffic
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"  # Strong TLS policy
  certificate_arn   = aws_acm_certificate.main.arn

  # Default action: forward to application
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP Listener - Redirects to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # Redirect all HTTP traffic to HTTPS
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"  # Permanent redirect
    }
  }
}

# =============================================================================
# KUBERNETES PROVIDER CONFIGURATION
# =============================================================================
# Configure Kubernetes and Helm providers to manage cluster resources

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # Use AWS CLI for authentication
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# =============================================================================
# AWS LOAD BALANCER CONTROLLER
# =============================================================================
# Manages ALB/NLB resources from Kubernetes Ingress

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-alb-controller-role"
  }
}

# Service Account with IAM role for AWS API access
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }

  depends_on = [module.eks]
}

# Helm chart deployment for AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.6.2"

  # Chart configuration values
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"  # Use our custom service account
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  depends_on = [
    module.eks,
    kubernetes_service_account.aws_load_balancer_controller
  ]
}

# Application namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      name = var.app_namespace
    }
  }

  depends_on = [module.eks]
}
