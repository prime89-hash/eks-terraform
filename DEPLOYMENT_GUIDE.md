# 🚀 Complete Deployment Guide: 3-Tier Web Application on AWS EKS

This comprehensive guide walks you through deploying a production-ready 3-tier web application on AWS EKS with Fargate, API Gateway, and complete monitoring stack.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [API Gateway Usage](#api-gateway-usage)
5. [Monitoring & Troubleshooting](#monitoring--troubleshooting)
6. [Security Best Practices](#security-best-practices)
7. [Cost Management](#cost-management)
8. [Cleanup](#cleanup)

## 🏗️ Architecture Overview

### 3-Tier Architecture Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  PRESENTATION   │    │   APPLICATION   │    │      DATA       │
│     TIER        │    │      TIER       │    │      TIER       │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ • API Gateway   │    │ • EKS Fargate   │    │ • RDS PostgreSQL│
│ • ALB + TLS     │    │ • Spring Boot   │    │ • Encryption    │
│ • WAF           │    │ • Auto Scaling  │    │ • Backup        │
│ • CloudFront    │    │ • Health Checks │    │ • Multi-AZ      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Traffic Flow

```
Internet → API Gateway → VPC Link → ALB → EKS Fargate → RDS
                    ↓
               CloudWatch Logs
                    ↓
            Prometheus/Grafana
```

## 📋 Prerequisites

### Required Tools

```bash
# Check if tools are installed
aws --version          # AWS CLI v2.x
terraform --version    # Terraform >= 1.5.0
kubectl version        # Kubernetes CLI
docker --version       # Docker for local builds
helm version          # Helm v3.x
```

### AWS Account Setup

1. **AWS Account with appropriate permissions**
2. **AWS CLI configured with credentials**
3. **Domain name registered (optional but recommended)**

### Required AWS Permissions

Your AWS user/role needs these permissions:
- `EKSFullAccess`
- `EC2FullAccess`
- `RDSFullAccess`
- `IAMFullAccess`
- `Route53FullAccess` (if using custom domain)
- `CertificateManagerFullAccess`
- `APIGatewayFullAccess`

## 🚀 Step-by-Step Deployment

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone <your-repository-url>
cd eks-terraform

# Copy and customize configuration
cp terraform.tfvars.example terraform.tfvars
```

### Step 2: Configure Variables

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "us-west-2"

# Project Configuration
project_name = "webapp-3tier"
environment = "prod"

# Domain Configuration (IMPORTANT: Use your domain)
domain_name = "yourdomain.com"  # Replace with your domain

# Database Configuration
db_password = "YourSecurePassword123!"  # Use a strong password

# Network Configuration (optional - defaults are fine)
vpc_cidr = "10.0.0.0/16"
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform with required providers
terraform init

# Validate configuration
terraform validate

# Format code (optional)
terraform fmt
```

### Step 4: Plan Deployment

```bash
# Create execution plan
terraform plan -var-file="terraform.tfvars"

# Review the plan carefully - it will create ~50+ resources
# Look for any errors or warnings
```

### Step 5: Deploy Infrastructure

```bash
# Apply the configuration (this takes 15-20 minutes)
terraform apply -var-file="terraform.tfvars"

# Type 'yes' when prompted
```

**What gets created:**
- VPC with public/private subnets across 3 AZs
- EKS cluster with Fargate profiles
- RDS PostgreSQL database
- Application Load Balancer
- API Gateway with custom domain
- ECR repository
- IAM roles and security groups
- Monitoring stack (Prometheus/Grafana)
- SSL certificates

### Step 6: Configure kubectl

```bash
# Update kubeconfig to connect to the new cluster
aws eks update-kubeconfig --region us-west-2 --name webapp-3tier-cluster

# Verify connection
kubectl cluster-info
kubectl get nodes  # Should show Fargate nodes
```

### Step 7: Build and Push Application

```bash
# Navigate to application directory
cd app

# Login to ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Build Docker image
docker build -t webapp-3tier .

# Tag and push to ECR
ECR_URL=$(cd .. && terraform output -raw ecr_repository_url)
docker tag webapp-3tier:latest $ECR_URL:latest
docker push $ECR_URL:latest

cd ..
```

### Step 8: Deploy Application to Kubernetes

```bash
# Get deployment values
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Update Kubernetes manifests
sed -i.bak "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" k8s/deployment.yaml

# Encode RDS endpoint for secret
RDS_ENDPOINT_B64=$(echo -n "$RDS_ENDPOINT" | base64)
sed -i.bak "s|db-host: # Base64 encoded RDS endpoint|db-host: $RDS_ENDPOINT_B64|g" k8s/deployment.yaml

# Deploy application
kubectl apply -f k8s/deployment.yaml

# Wait for deployment
kubectl rollout status deployment/webapp-3tier -n webapp --timeout=300s
```

### Step 9: Configure Ingress

```bash
# Get required values for ingress
CERTIFICATE_ARN=$(terraform output -raw certificate_arn)
ALB_SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=webapp-3tier-alb-*" \
  --query 'SecurityGroups[0].GroupId' --output text)
PUBLIC_SUBNETS=$(terraform output -json public_subnets | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

# Update ingress manifest
sed -i.bak "s|CERTIFICATE_ARN|$CERTIFICATE_ARN|g" k8s/ingress.yaml
sed -i.bak "s|ALB_SECURITY_GROUP_ID|$ALB_SG_ID|g" k8s/ingress.yaml
sed -i.bak "s|PUBLIC_SUBNET_IDS|$PUBLIC_SUBNETS|g" k8s/ingress.yaml

# Deploy ingress
kubectl apply -f k8s/ingress.yaml

# Wait for ALB to be created (takes 2-3 minutes)
kubectl get ingress -n webapp -w
```

### Step 10: Verify Deployment

```bash
# Check all resources
kubectl get all -n webapp

# Check application logs
kubectl logs -n webapp deployment/webapp-3tier

# Get ALB DNS name
ALB_DNS=$(kubectl get ingress webapp-ingress -n webapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: https://$ALB_DNS"

# Test health endpoint
curl -k https://$ALB_DNS/health
```

## 🌐 API Gateway Usage

### API Gateway Endpoints

After deployment, you'll have these endpoints:

```bash
# Get API Gateway URLs
API_GATEWAY_URL=$(terraform output -raw api_gateway_url)
CUSTOM_API_URL=$(terraform output -raw api_gateway_custom_domain)
API_KEY=$(terraform output -raw api_key)

echo "API Gateway URL: $API_GATEWAY_URL"
echo "Custom Domain: $CUSTOM_API_URL"
echo "API Key: $API_KEY"
```

### Available API Endpoints

| Method | Endpoint | Description | Authentication |
|--------|----------|-------------|----------------|
| GET | `/health` | Health check | None |
| GET | `/v1/users` | Get all users | IAM |
| POST | `/v1/users` | Create user | IAM |
| GET | `/v1/users/{id}` | Get user by ID | IAM |

### Testing API Gateway

```bash
# Health check (no authentication)
curl -X GET "$API_GATEWAY_URL/health"

# Get users (requires IAM authentication)
curl -X GET "$API_GATEWAY_URL/v1/users" \
  -H "x-api-key: $API_KEY"

# Create user (requires IAM authentication)
curl -X POST "$API_GATEWAY_URL/v1/users" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "age": 30
  }'

# Get specific user
curl -X GET "$API_GATEWAY_URL/v1/users/1" \
  -H "x-api-key: $API_KEY"
```

### API Gateway Features

1. **Rate Limiting**: 1000 requests/second, 2000 burst
2. **Request Validation**: JSON schema validation
3. **Error Handling**: Standardized error responses
4. **Logging**: CloudWatch access logs
5. **Monitoring**: CloudWatch metrics
6. **Custom Domain**: SSL/TLS with ACM certificate

## 📊 Monitoring & Troubleshooting

### Access Monitoring Dashboards

```bash
# Grafana Dashboard
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access: http://localhost:3000 (admin/admin123)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Access: http://localhost:9090
```

### CloudWatch Dashboards

1. **EKS Cluster Metrics**: Container Insights
2. **API Gateway Metrics**: Request count, latency, errors
3. **ALB Metrics**: Target health, response times
4. **RDS Metrics**: CPU, connections, storage

### Common Troubleshooting

#### 1. Pod Not Starting

```bash
# Check pod status
kubectl get pods -n webapp

# Check pod events
kubectl describe pod -n webapp <pod-name>

# Check logs
kubectl logs -n webapp <pod-name>
```

#### 2. Database Connection Issues

```bash
# Test database connectivity from pod
kubectl exec -it -n webapp deployment/webapp-3tier -- \
  nc -zv <rds-endpoint> 5432

# Check security groups
aws ec2 describe-security-groups --group-ids <rds-sg-id>
```

#### 3. API Gateway Issues

```bash
# Check API Gateway logs
aws logs tail /aws/apigateway/webapp-3tier --follow

# Test VPC Link
aws apigateway get-vpc-link --vpc-link-id <vpc-link-id>
```

#### 4. Load Balancer Issues

```bash
# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check ingress status
kubectl describe ingress -n webapp webapp-ingress
```

## 🔐 Security Best Practices

### Network Security

1. **Private Subnets**: EKS nodes and RDS in private subnets
2. **Security Groups**: Least privilege access rules
3. **VPC Flow Logs**: Network traffic monitoring
4. **WAF**: Web application firewall protection

### Application Security

1. **Non-root Containers**: Containers run as non-root user
2. **Read-only Filesystem**: Container filesystem is read-only
3. **Network Policies**: Pod-to-pod communication restrictions
4. **Image Scanning**: ECR vulnerability scanning enabled

### Data Security

1. **Encryption at Rest**: RDS and EBS volumes encrypted
2. **Encryption in Transit**: TLS 1.2+ for all communications
3. **Secrets Management**: AWS Secrets Manager for credentials
4. **Database Access**: Only from application pods

### API Security

1. **API Keys**: Required for API access
2. **Rate Limiting**: Prevents abuse
3. **Request Validation**: Input validation and sanitization
4. **HTTPS Only**: All API traffic encrypted

## 💰 Cost Management

### Estimated Monthly Costs (us-west-2)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| EKS Cluster | Control plane | $73 |
| Fargate | 3 pods (0.25 vCPU, 0.5GB) | $30 |
| RDS | db.t3.micro | $13 |
| ALB | Application Load Balancer | $23 |
| NAT Gateway | 3 AZs | $135 |
| API Gateway | 1M requests | $3.50 |
| **Total** | | **~$277** |

### Cost Optimization Tips

1. **Use Spot Instances**: For non-production workloads
2. **Right-size Resources**: Monitor and adjust based on usage
3. **Reserved Instances**: For predictable workloads
4. **Auto Scaling**: Scale down during low usage
5. **Data Transfer**: Minimize cross-AZ traffic

## 🧹 Cleanup

### Complete Infrastructure Cleanup

```bash
# Delete Kubernetes resources first
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/deployment.yaml

# Wait for ALB to be deleted
sleep 60

# Destroy Terraform resources
terraform destroy -var-file="terraform.tfvars"

# Type 'yes' when prompted
```

### Partial Cleanup (Keep Infrastructure)

```bash
# Delete only application resources
kubectl delete -f k8s/
helm uninstall prometheus -n monitoring
```

## 🎯 Next Steps

After successful deployment:

1. **Configure DNS**: Point your domain to the ALB
2. **Set up CI/CD**: Use the included GitHub Actions workflow
3. **Configure Monitoring**: Set up alerts and dashboards
4. **Security Hardening**: Implement additional security measures
5. **Performance Tuning**: Optimize based on load testing results

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review CloudWatch logs
3. Verify all prerequisites are met
4. Check AWS service limits
5. Review Terraform state for inconsistencies

## 📚 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Spring Boot Production Guide](https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html)
- [API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
