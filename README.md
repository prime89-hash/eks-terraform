# 3-Tier Web Application on AWS EKS with Fargate

<!-- CI/CD Pipeline Test - Deployment Ready -->

A production-ready 3-tier web application deployed on AWS EKS using Fargate, with comprehensive security, monitoring, and CI/CD capabilities.

## 📚 Complete Documentation

### 🚀 **[END-TO-END DEPLOYMENT GUIDE](./END_TO_END_GUIDE.md)**
**→ Start here for complete step-by-step instructions**
- Complete architecture explanation
- Prerequisites and setup
- Detailed deployment steps
- Code structure walkthrough
- Testing and validation

### 🏗️ **[ARCHITECTURE DOCUMENTATION](./ARCHITECTURE.md)**
**→ Understand the system design**
- Detailed architecture diagrams
- Network topology
- Security layers
- Scaling strategies
- Disaster recovery

### 📊 **[MONITORING GUIDE](./MONITORING_GUIDE.md)**
**→ Learn about observability**
- Prometheus and Grafana setup
- Custom dashboards
- Alerting configuration
- Troubleshooting monitoring

### 🔧 **[DEPLOYMENT GUIDE](./DEPLOYMENT_GUIDE.md)**
**→ Detailed deployment instructions**
- Manual deployment steps
- CI/CD pipeline setup
- Configuration options
- Best practices

## 🏗️ Architecture Overview

### 3-Tier Architecture
- **Presentation Tier**: API Gateway + Application Load Balancer with TLS
- **Application Tier**: Java Spring Boot on EKS Fargate with auto-scaling
- **Data Tier**: Amazon RDS PostgreSQL with encryption and backups

### Key Features
- ✅ **Serverless Compute**: EKS Fargate for zero server management
- ✅ **Complete Monitoring**: Prometheus, Grafana, CloudWatch integration
- ✅ **Production Security**: WAF, encryption, network isolation, IAM
- ✅ **Auto-scaling**: Horizontal Pod Autoscaler based on CPU/memory
- ✅ **CI/CD Pipeline**: GitHub Actions with OIDC authentication
- ✅ **High Availability**: Multi-AZ deployment across 3 availability zones

## 🚀 Quick Start

### Option 1: One-Command Deployment
```bash
git clone https://github.com/prime89-hash/eks-terraform.git
cd eks-terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
./deploy.sh
```

### Option 2: CI/CD Pipeline
1. Fork this repository
2. Configure GitHub secrets: `AWS_ROLE_ARN`
3. Push to main branch → automatic deployment

### Option 3: Manual Terraform
```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## 📊 What Gets Deployed

### AWS Infrastructure (134+ Resources)
- **EKS Cluster**: Fargate-only with managed add-ons
- **VPC**: 3 public + 3 private subnets across 3 AZs
- **RDS**: PostgreSQL with encryption and automated backups
- **API Gateway**: REST API with VPC Link and custom domain
- **Load Balancers**: ALB for HTTPS + NLB for VPC Link
- **Security**: WAF, KMS encryption, Secrets Manager
- **Monitoring**: Complete Prometheus/Grafana stack

### Application Stack
- **Backend**: Java 17 + Spring Boot 3.1.5
- **Container**: Multi-stage Docker build with security best practices
- **Metrics**: Micrometer + Prometheus integration
- **Health Checks**: Kubernetes probes + application endpoints

## 🔍 Access Your Application

After deployment, access your application:

```bash
# Get deployment information
terraform output deployment_summary

# Access Grafana monitoring
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open: http://localhost:3000 (admin/admin123)

# Test API endpoints
./test-api.sh
```

## 💰 Cost Estimate

**Monthly costs (us-west-2):**
- EKS Cluster: $73
- Fargate (3 pods): $30
- RDS t3.micro: $13
- ALB: $23
- NAT Gateways: $135
- API Gateway: $3.50
- **Total: ~$277/month**

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

## 📈 Monitoring & Observability

### Included Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization with pre-built dashboards
- **AlertManager**: Alert handling and notifications
- **CloudWatch**: AWS native monitoring and logging
- **Container Insights**: EKS-specific metrics

### Pre-configured Dashboards
- Kubernetes Cluster Overview (Grafana ID: 7249)
- Node Exporter Dashboard (Grafana ID: 1860)
- Spring Boot Application Dashboard (Grafana ID: 12900)
- Custom CloudWatch dashboard for AWS resources

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
The repository includes a complete CI/CD pipeline:

1. **Test**: Runs unit tests and builds the application
2. **Infrastructure Deploy**: Creates all AWS resources with Terraform
3. **Build & Push**: Creates Docker image and pushes to ECR
4. **Application Deploy**: Deploys to Kubernetes with rolling updates

### Pipeline Features
- **OIDC Authentication**: Secure AWS access without long-lived credentials
- **Terraform State**: Managed state with proper locking
- **Docker Multi-stage**: Optimized container builds
- **Rolling Deployments**: Zero-downtime application updates

## 🧪 Testing

### Automated Testing
```bash
# Run comprehensive API test suite
./test-api.sh

# Load testing
hey -n 1000 -c 10 https://your-application-url/
```

### Health Checks
```bash
# Application health
curl https://your-alb-dns/health

# API Gateway health  
curl https://your-api-gateway-url/health

# Kubernetes health
kubectl get pods -n webapp
```

## 🔧 Troubleshooting

### Common Issues
- **EKS Access**: Update kubeconfig with `aws eks update-kubeconfig`
- **Pod Issues**: Check logs with `kubectl logs -n webapp deployment/webapp-3tier`
- **Database**: Verify security groups and network connectivity
- **API Gateway**: Check VPC Link status and NLB health

### Debugging Commands
```bash
# Get all resources
kubectl get all -n webapp

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp

# View application logs
kubectl logs -f deployment/webapp-3tier -n webapp
```

## 📚 Additional Resources

- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Spring Boot Production Best Practices](https://docs.spring.io/spring-boot/docs/current/reference/html/deployment.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

🎉 **Ready to deploy?** Start with the **[END-TO-END DEPLOYMENT GUIDE](./END_TO_END_GUIDE.md)** for complete instructions!