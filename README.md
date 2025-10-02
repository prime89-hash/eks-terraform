# 3-Tier Web Application on AWS EKS with Fargate

A production-ready 3-tier web application deployed on AWS EKS using Fargate, with comprehensive security, monitoring, and CI/CD capabilities.

## 🏗️ Architecture Overview

### 3-Tier Architecture
- **Presentation Tier**: Application Load Balancer (ALB) with TLS termination
- **Application Tier**: Java Spring Boot application running on EKS Fargate
- **Data Tier**: Amazon RDS PostgreSQL with encryption at rest

### AWS Services Used
- **EKS Fargate**: Serverless Kubernetes compute
- **ECR**: Container registry for Docker images
- **ALB**: Application Load Balancer with TLS
- **RDS**: PostgreSQL database with encryption
- **VPC**: Private/public subnets across 3 AZs
- **ACM**: SSL/TLS certificates
- **WAF**: Web Application Firewall
- **CloudWatch**: Monitoring and logging
- **Secrets Manager**: Secure credential storage
- **KMS**: Encryption key management

## 🔒 Security Features

### Network Security
- Private subnets for EKS nodes and RDS
- Security groups with least privilege access
- VPC Flow Logs for network monitoring
- WAF with managed rule sets and rate limiting

### Application Security
- Non-root container execution
- Read-only root filesystem
- Security contexts and capabilities dropping
- Network policies for pod-to-pod communication
- HTTPS-only with TLS 1.2+

### Data Security
- RDS encryption at rest with KMS
- Secrets Manager for credential management
- ECR image scanning enabled
- Container image vulnerability scanning

## 🚀 Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0
- kubectl
- Docker (for local development)

### 1. Clone and Configure
```bash
git clone <repository-url>
cd eks-terraform

# Update variables in variables.tf or create terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
```

### 2. Deploy Infrastructure
```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var="environment=prod"

# Deploy infrastructure
terraform apply -var="environment=prod"
```

### 3. Configure kubectl
```bash
aws eks update-kubeconfig --region us-west-2 --name webapp-3tier-cluster
```

### 4. Deploy Application
```bash
# Update Kubernetes manifests with your values
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress.yaml
```

## 🔧 Configuration

### Environment Variables
Create `terraform.tfvars`:
```hcl
aws_region = "us-west-2"
project_name = "webapp-3tier"
environment = "prod"
domain_name = "yourdomain.com"
db_password = "YourSecurePassword123!"
```

### Required AWS Permissions
Your AWS user/role needs:
- EKS cluster management
- EC2 and VPC management
- RDS management
- ECR repository management
- IAM role creation
- ACM certificate management
- Route53 (if using custom domain)

## 🏃‍♂️ CI/CD Pipeline

### GitHub Actions Workflow
The repository includes a complete CI/CD pipeline:

1. **Test**: Runs unit tests and builds the application
2. **Build & Push**: Creates Docker image and pushes to ECR
3. **Deploy Infrastructure**: Applies Terraform changes
4. **Deploy Application**: Updates Kubernetes deployments

### Setup CI/CD
1. Fork this repository
2. Configure GitHub secrets:
   - `AWS_ROLE_ARN`: OIDC role for GitHub Actions
3. Push to main branch to trigger deployment

### Manual Deployment Trigger
```bash
# Deploy
gh workflow run deploy.yml -f action=deploy

# Destroy
gh workflow run deploy.yml -f action=destroy
```

## 📊 Monitoring & Observability

### Included Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **CloudWatch**: AWS native monitoring
- **Container Insights**: EKS-specific metrics
- **X-Ray**: Distributed tracing

### Access Monitoring
```bash
# Get Grafana admin password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

# Port forward to access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### CloudWatch Dashboards
- Application Load Balancer metrics
- RDS database performance
- EKS cluster health
- Custom application metrics

## 🧪 Testing

### Local Development
```bash
cd app
./gradlew bootRun
```

### Health Checks
```bash
# Application health
curl https://your-domain.com/health

# Kubernetes health
kubectl get pods -n webapp
kubectl describe deployment webapp-3tier -n webapp
```

### Load Testing
```bash
# Install hey for load testing
go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 https://your-domain.com/
```

## 🔍 Troubleshooting

### Common Issues

**1. EKS Cluster Access**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name webapp-3tier-cluster

# Check cluster status
kubectl cluster-info
```

**2. Pod Startup Issues**
```bash
# Check pod logs
kubectl logs -n webapp deployment/webapp-3tier

# Check pod events
kubectl describe pod -n webapp -l app=webapp-3tier
```

**3. Database Connectivity**
```bash
# Test database connection
kubectl exec -it -n webapp deployment/webapp-3tier -- nc -zv <rds-endpoint> 5432
```

**4. Load Balancer Issues**
```bash
# Check ALB status
kubectl describe ingress -n webapp webapp-ingress

# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

### Debugging Commands
```bash
# Check all resources
kubectl get all -n webapp

# Check secrets
kubectl get secrets -n webapp

# Check service accounts
kubectl get serviceaccounts -n webapp

# Check network policies
kubectl get networkpolicies -n webapp
```

## 💰 Cost Optimization

### Estimated Monthly Costs (us-west-2)
- **EKS Cluster**: $73/month
- **Fargate**: ~$30/month (3 pods, 0.25 vCPU, 0.5GB each)
- **RDS t3.micro**: ~$13/month
- **ALB**: ~$23/month
- **NAT Gateway**: ~$45/month
- **Data Transfer**: Variable

**Total Estimated**: ~$184/month

### Cost Reduction Tips
- Use Spot instances for non-production
- Implement pod autoscaling
- Use RDS reserved instances
- Monitor and optimize data transfer

## 🔐 Security Best Practices

### Implemented Security Measures
- ✅ Network segmentation with private subnets
- ✅ Security groups with minimal access
- ✅ WAF with managed rules
- ✅ TLS encryption in transit
- ✅ Encryption at rest (RDS, EBS)
- ✅ Non-root container execution
- ✅ Image vulnerability scanning
- ✅ Secrets management with AWS Secrets Manager
- ✅ IAM roles with least privilege
- ✅ VPC Flow Logs for monitoring

### Additional Recommendations
- Implement pod security policies
- Use admission controllers
- Regular security audits
- Implement backup strategies
- Monitor for compliance violations

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Spring Boot Production Best Practices](https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.