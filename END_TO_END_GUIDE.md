# 🚀 Complete End-to-End Guide: 3-Tier Web Application on AWS EKS

This comprehensive guide walks you through understanding, deploying, and managing a production-ready 3-tier web application on AWS EKS with complete monitoring and CI/CD pipeline.

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Technology Stack](#technology-stack)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Understanding the Code Structure](#understanding-the-code-structure)
6. [Monitoring & Observability](#monitoring--observability)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Testing & Validation](#testing--validation)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## 🏗️ Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────┐
│                    PRESENTATION TIER                                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   API Gateway   │  │  CloudFront     │  │      WAF        │             │
│  │  • Rate Limit   │  │  • CDN          │  │  • Security     │             │
│  │  • Auth         │  │  • Caching      │  │  • DDoS Protect │             │
│  │  • Transform    │  │  • SSL/TLS      │  │  • Bot Control  │             │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘             │
└─────────────────────────┬───────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────┐
│                      AWS VPC (10.0.0.0/16)                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PUBLIC SUBNETS                                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │   │
│  │  │     ALB     │  │ NAT Gateway │  │   Bastion   │                 │   │
│  │  │ us-west-2a  │  │ us-west-2b  │  │ us-west-2c  │                 │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                 │   │
│  └─────────────────────┬───────────────────────────────────────────────┘   │
│                        │                                                   │
│  ┌─────────────────────▼───────────────────────────────────────────────┐   │
│  │                   PRIVATE SUBNETS                                   │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                APPLICATION TIER                             │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────────────────────────────────────────────┐   │   │   │
│  │  │  │              EKS FARGATE CLUSTER                    │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │   │   │
│  │  │  │  │   Pod 1     │  │   Pod 2     │  │   Pod 3     │ │   │   │   │
│  │  │  │  │Spring Boot  │  │Spring Boot  │  │Spring Boot  │ │   │   │   │
│  │  │  │  │   App       │  │   App       │  │   App       │ │   │   │   │
│  │  │  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │   │   │
│  │  │  │                                                     │   │   │   │
│  │  │  │  ┌─────────────────────────────────────────────┐   │   │   │   │
│  │  │  │  │            MONITORING STACK                 │   │   │   │   │
│  │  │  │  │  ┌─────────┐ ┌─────────┐ ┌─────────────┐   │   │   │   │   │
│  │  │  │  │  │Prometheus│ │ Grafana │ │AlertManager │   │   │   │   │   │
│  │  │  │  │  └─────────┘ └─────────┘ └─────────────┘   │   │   │   │   │
│  │  │  │  └─────────────────────────────────────────────┘   │   │   │   │
│  │  │  └─────────────────────────────────────────────────────┘   │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                     │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                     DATA TIER                               │   │   │
│  │  │                                                             │   │   │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐     │   │   │
│  │  │  │     RDS     │  │   Secrets   │  │      KMS        │     │   │   │
│  │  │  │ PostgreSQL  │  │  Manager    │  │   Encryption    │     │   │   │
│  │  │  │Multi-AZ     │  │             │  │     Keys        │     │   │   │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────┘     │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Component Flow

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│ API Gateway │───▶│  VPC Link   │───▶│     NLB     │
│  (Browser)  │    │• Rate Limit │    │• Private    │    │• Internal   │
│             │    │• Auth       │    │• Secure     │    │• TCP        │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                  │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│     RDS     │◀───│ EKS Fargate │◀───│     ALB     │◀───┘             │
│ PostgreSQL  │    │Spring Boot  │    │• HTTPS      │                  │
│• Encrypted  │    │• Metrics    │    │• Health     │                  │
│• Multi-AZ   │    │• Logging    │    │• SSL Term   │                  │
└─────────────┘    └─────────────┘    └─────────────┘                  │
                           │                                           │
┌─────────────┐    ┌─────────────┐    ┌─────────────┐                  │
│ Prometheus  │◀───│  Grafana    │    │ CloudWatch  │                  │
│• Metrics    │    │• Dashboard  │    │• AWS Logs   │                  │
│• Alerts     │    │• Visualize  │    │• Alarms     │                  │
└─────────────┘    └─────────────┘    └─────────────┘                  │
```

## 🛠️ Technology Stack

### Infrastructure & Platform
- **Cloud Provider**: AWS
- **Container Orchestration**: Amazon EKS (Fargate)
- **Infrastructure as Code**: Terraform
- **Container Registry**: Amazon ECR
- **Load Balancing**: Application Load Balancer (ALB) + Network Load Balancer (NLB)

### Application Stack
- **Backend**: Java 17 + Spring Boot 3.1.5
- **Build Tool**: Gradle 8.4
- **Database**: PostgreSQL 15.7 (Amazon RDS)
- **API Gateway**: AWS API Gateway with VPC Link

### Monitoring & Observability
- **Metrics**: Prometheus + Micrometer
- **Visualization**: Grafana
- **Alerting**: AlertManager + AWS CloudWatch
- **Logging**: CloudWatch Logs + Container Insights
- **Tracing**: AWS X-Ray (optional)

### Security
- **Network**: VPC with private/public subnets
- **Encryption**: KMS for encryption at rest, TLS for in-transit
- **Secrets**: AWS Secrets Manager
- **Web Security**: AWS WAF
- **Access Control**: IAM roles with least privilege

### CI/CD
- **Version Control**: GitHub
- **CI/CD**: GitHub Actions
- **Authentication**: OIDC (OpenID Connect)
- **Deployment**: Automated with Terraform + kubectl

## 📋 Prerequisites

### Required Tools
```bash
# Check if tools are installed
aws --version          # AWS CLI v2.x
terraform --version    # Terraform >= 1.5.0
kubectl version        # Kubernetes CLI
docker --version       # Docker for local builds
helm version          # Helm v3.x
git --version         # Git for version control
```

### AWS Account Requirements
1. **AWS Account** with administrative access
2. **Domain name** (optional, can use example.com for testing)
3. **GitHub repository** for CI/CD pipeline

### Required AWS Permissions
Your AWS user/role needs these managed policies:
- `AmazonEKSClusterPolicy`
- `AmazonEC2FullAccess`
- `IAMFullAccess`
- `AmazonRDSFullAccess`
- `AmazonAPIGatewayAdministrator`
- `AmazonEC2ContainerRegistryFullAccess`

## 🚀 Step-by-Step Deployment

### Step 1: Repository Setup

```bash
# Clone the repository
git clone https://github.com/prime89-hash/eks-terraform.git
cd eks-terraform

# Review the project structure
tree -L 2
```

### Step 2: Configure Variables

```bash
# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your specific values
nano terraform.tfvars
```

**Required Configuration:**
```hcl
# AWS Configuration
aws_region = "us-west-2"

# Project Configuration
project_name = "webapp-3tier"
environment = "prod"

# Domain Configuration (use your domain or keep example.com)
domain_name = "yourdomain.com"  # or "example.com" for testing

# Database Configuration
db_password = "YourSecurePassword123!"  # Use a strong password

# Network Configuration (optional - defaults are fine)
vpc_cidr = "10.0.0.0/16"
```

### Step 3: IAM Role Setup (for CI/CD)

```bash
# Update the githubactionagenticai role with required permissions
cd iam-policies

# Option 1: Use the automated script
./update-role-commands.sh

# Option 2: Manual policy attachment
aws iam attach-role-policy \
    --role-name githubactionagenticai \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy \
    --role-name githubactionagenticai \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

# Add other required policies...
```

### Step 4: Local Deployment (Optional)

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (review what will be created)
terraform plan -var-file="terraform.tfvars"

# Apply deployment (takes ~25 minutes)
terraform apply -var-file="terraform.tfvars"
```

### Step 5: CI/CD Pipeline Setup

```bash
# Configure GitHub secrets in your repository:
# Go to: Settings → Secrets and variables → Actions

# Add secret:
# Name: AWS_ROLE_ARN
# Value: arn:aws:iam::YOUR_ACCOUNT_ID:role/githubactionagenticai

# Push to main branch to trigger deployment
git add .
git commit -m "Initial deployment"
git push origin main
```

### Step 6: Post-Deployment Configuration

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name webapp-3tier-cluster

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Check application deployment
kubectl get pods -n webapp
kubectl get services -n webapp
kubectl get ingress -n webapp
```

### Step 7: Access Your Application

```bash
# Get application URLs
terraform output deployment_summary

# Test API Gateway
API_URL=$(terraform output -raw api_gateway_url)
curl $API_URL/health

# Test application directly
ALB_DNS=$(terraform output -raw load_balancer_dns)
curl https://$ALB_DNS/health
```

## 📁 Understanding the Code Structure

### Project Layout
```
eks-terraform/
├── 📄 main.tf                    # Core infrastructure (EKS, VPC, RDS)
├── 📄 api-gateway.tf            # API Gateway with VPC Link
├── 📄 iam.tf                    # IAM roles and policies
├── 📄 security.tf               # Security configurations (KMS, WAF, Secrets)
├── 📄 monitoring.tf             # Prometheus, Grafana, CloudWatch
├── 📄 variables.tf              # Input variables
├── 📄 outputs.tf                # Output values
├── 📄 terraform.tfvars.example  # Configuration template
├── 📄 deploy.sh                 # One-command deployment script
├── 📄 test-api.sh              # API testing script
├── 📁 .github/workflows/        # CI/CD pipeline
│   └── 📄 deploy.yml
├── 📁 app/                      # Java Spring Boot application
│   ├── 📄 build.gradle          # Build configuration
│   ├── 📄 Dockerfile            # Container image
│   ├── 📁 src/main/java/        # Application source code
│   └── 📁 src/main/resources/   # Configuration files
├── 📁 k8s/                      # Kubernetes manifests
│   ├── 📄 deployment.yaml       # Application deployment
│   └── 📄 ingress.yaml          # ALB ingress configuration
├── 📁 iam-policies/             # IAM policy documents
└── 📄 MONITORING_GUIDE.md       # Monitoring documentation
```

### Key Components Explained

#### 1. Infrastructure (main.tf)
```hcl
# Creates the foundation: VPC, EKS, RDS, ALB
module "vpc" {
  # 3 public + 3 private subnets across 3 AZs
}

module "eks" {
  # Fargate-only EKS cluster with managed add-ons
}

resource "aws_db_instance" "main" {
  # PostgreSQL with encryption and backups
}
```

#### 2. API Gateway (api-gateway.tf)
```hcl
# API Gateway → VPC Link → NLB → ALB → EKS
resource "aws_api_gateway_rest_api" "main" {
  # REST API with rate limiting and validation
}

resource "aws_api_gateway_vpc_link" "main" {
  # Secure connection to private resources
}
```

#### 3. Application (app/)
```java
@RestController
public class HealthController {
    // Spring Boot REST API with metrics
    // Exposes /health, /api/users endpoints
    // Prometheus metrics at /actuator/prometheus
}
```

#### 4. Monitoring (monitoring.tf)
```hcl
resource "helm_release" "prometheus" {
  # Complete monitoring stack:
  # - Prometheus for metrics collection
  # - Grafana for visualization
  # - AlertManager for notifications
}
```

## 📊 Monitoring & Observability

### Architecture
```
Application → Micrometer → Prometheus → Grafana
     ↓             ↓           ↓          ↓
  Metrics      Collection   Storage   Visualization
```

### Access Monitoring

#### Grafana Dashboard
```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open browser: http://localhost:3000
# Login: admin / admin123
```

#### Available Dashboards
1. **Kubernetes Cluster Overview** - Resource usage, pod status
2. **Node Exporter** - System metrics (CPU, memory, disk)
3. **Spring Boot Application** - JVM, HTTP requests, custom metrics
4. **CloudWatch Dashboard** - AWS resources (ALB, RDS, EKS)

#### Key Metrics
- **Application**: HTTP requests, response times, error rates
- **Infrastructure**: CPU, memory, disk usage
- **Database**: Connections, query performance
- **Kubernetes**: Pod restarts, resource utilization

### Alerting
- **Email notifications** via SNS
- **CloudWatch alarms** for AWS resources
- **Prometheus alerts** for application metrics
- **Custom alert rules** for business metrics

## 🔄 CI/CD Pipeline

### Pipeline Architecture
```
GitHub Push → GitHub Actions → AWS (OIDC) → Deploy Infrastructure → Build App → Deploy to EKS
```

### Pipeline Stages

#### 1. Test Stage
```yaml
- name: Run tests
  run: ./gradlew test --no-daemon
```

#### 2. Infrastructure Deployment
```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve
```

#### 3. Application Build & Push
```yaml
- name: Build and push Docker image
  run: |
    docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
    docker push $ECR_REPOSITORY:$IMAGE_TAG
```

#### 4. Kubernetes Deployment
```yaml
- name: Deploy to EKS
  run: |
    kubectl apply -f k8s/deployment.yaml
    kubectl rollout status deployment/webapp-3tier
```

### Manual Triggers
```bash
# Deploy infrastructure
gh workflow run deploy.yml -f action=deploy

# Destroy infrastructure
gh workflow run deploy.yml -f action=destroy
```

## 🧪 Testing & Validation

### Automated Testing
```bash
# Run the comprehensive API test suite
./test-api.sh
```

### Manual Testing

#### 1. Health Checks
```bash
# Application health
curl https://your-alb-dns/health

# API Gateway health
curl https://your-api-gateway-url/health
```

#### 2. API Endpoints
```bash
# Get users (requires API key)
curl -X GET "https://your-api-gateway-url/v1/users" \
  -H "x-api-key: your-api-key"

# Create user
curl -X POST "https://your-api-gateway-url/v1/users" \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

#### 3. Monitoring Validation
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit: http://localhost:9090/targets

# Check Grafana dashboards
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Visit: http://localhost:3000
```

#### 4. Load Testing
```bash
# Install hey for load testing
go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 https://your-application-url/
```

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. EKS Cluster Access Issues
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name webapp-3tier-cluster

# Check cluster status
kubectl cluster-info

# Verify IAM permissions
aws sts get-caller-identity
```

#### 2. Pod Startup Problems
```bash
# Check pod status
kubectl get pods -n webapp

# View pod logs
kubectl logs -n webapp deployment/webapp-3tier

# Describe pod for events
kubectl describe pod -n webapp -l app=webapp-3tier
```

#### 3. Database Connection Issues
```bash
# Test database connectivity
kubectl exec -it -n webapp deployment/webapp-3tier -- \
  nc -zv your-rds-endpoint 5432

# Check security groups
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

#### 4. API Gateway Issues
```bash
# Check VPC Link status
aws apigateway get-vpc-link --vpc-link-id xxxxx

# Test NLB connectivity
aws elbv2 describe-target-health --target-group-arn arn:aws:...
```

#### 5. Monitoring Issues
```bash
# Check Prometheus targets
kubectl get servicemonitor -n monitoring

# Verify metrics endpoint
kubectl port-forward -n webapp svc/webapp-service 8080:80
curl http://localhost:8080/actuator/prometheus
```

### Debugging Commands
```bash
# Get all resources
kubectl get all -A

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# View logs
kubectl logs -f deployment/webapp-3tier -n webapp

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## 💡 Best Practices

### Security
- ✅ Use least privilege IAM roles
- ✅ Enable encryption at rest and in transit
- ✅ Implement network segmentation
- ✅ Regular security updates
- ✅ Monitor for security events

### Performance
- ✅ Right-size resources based on monitoring
- ✅ Use horizontal pod autoscaling
- ✅ Implement caching strategies
- ✅ Optimize database queries
- ✅ Monitor and tune JVM settings

### Reliability
- ✅ Multi-AZ deployment
- ✅ Health checks and readiness probes
- ✅ Circuit breaker patterns
- ✅ Graceful shutdown handling
- ✅ Backup and disaster recovery

### Cost Optimization
- ✅ Use Fargate for serverless compute
- ✅ Implement auto-scaling
- ✅ Monitor and optimize resource usage
- ✅ Use reserved instances for predictable workloads
- ✅ Regular cost reviews

### Monitoring
- ✅ Monitor what matters to your business
- ✅ Set up meaningful alerts
- ✅ Use dashboards for different audiences
- ✅ Regular review and tuning
- ✅ Document runbooks for common issues

## 📞 Support & Next Steps

### Getting Help
1. **Check this guide** for common issues
2. **Review logs** in CloudWatch and kubectl
3. **Check monitoring** dashboards for insights
4. **Verify configuration** against examples
5. **Test connectivity** between components

### Next Steps
1. **Customize** the application for your use case
2. **Add** additional monitoring and alerting
3. **Implement** backup and disaster recovery
4. **Set up** development and staging environments
5. **Add** additional security measures

### Useful Resources
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [Spring Boot Documentation](https://spring.io/projects/spring-boot)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

🎉 **Congratulations!** You now have a complete understanding of the 3-tier web application architecture and how to deploy, monitor, and maintain it. This production-ready setup provides a solid foundation for building scalable, secure, and observable applications on AWS.
