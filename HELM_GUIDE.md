# 📦 Helm Deployment Guide

This guide explains how to use Helm for deploying the 3-tier web application.

## 🏗️ Helm Chart Structure

```
helm/webapp-3tier/
├── Chart.yaml                 # Chart metadata
├── values.yaml               # Default configuration values
└── templates/
    ├── _helpers.tpl          # Template helpers
    ├── deployment.yaml       # Application deployment
    ├── service.yaml          # Kubernetes service
    ├── serviceaccount.yaml   # Service account
    ├── ingress.yaml          # ALB ingress
    ├── hpa.yaml              # Horizontal Pod Autoscaler
    └── servicemonitor.yaml   # Prometheus ServiceMonitor
```

## 🚀 Quick Deployment

### Prerequisites
```bash
# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm installation
helm version
```

### Deploy Application
```bash
# Deploy infrastructure first
terraform apply -var-file="terraform.tfvars"

# Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name webapp-3tier-cluster

# Get required values
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Create database secret
kubectl create secret generic webapp-secrets -n webapp \
  --from-literal=db-host="$RDS_ENDPOINT" \
  --from-literal=db-name="webapp" \
  --from-literal=db-username="webapp_user" \
  --from-literal=db-password="YourSecurePassword123!" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy with Helm
helm upgrade --install webapp-3tier ./helm/webapp-3tier \
  --namespace webapp \
  --create-namespace \
  --set image.repository="$ECR_REPO" \
  --set image.tag="latest" \
  --wait --timeout=300s
```

## ⚙️ Configuration Options

### Image Configuration
```yaml
image:
  repository: your-account.dkr.ecr.us-west-2.amazonaws.com/webapp-3tier-app
  tag: "v1.0.0"
  pullPolicy: Always
```

### Scaling Configuration
```yaml
replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### Resource Limits
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### Ingress Configuration
```yaml
ingress:
  enabled: true
  className: "alb"
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..."
  hosts:
    - host: webapp.example.com
      paths:
        - path: /
          pathType: Prefix
```

### Monitoring Configuration
```yaml
monitoring:
  serviceMonitor:
    enabled: true
    namespace: monitoring
    interval: 30s
    path: /actuator/prometheus
```

## 🔧 Helm Commands

### Install/Upgrade
```bash
# Install new release
helm install webapp-3tier ./helm/webapp-3tier -n webapp --create-namespace

# Upgrade existing release
helm upgrade webapp-3tier ./helm/webapp-3tier -n webapp

# Install or upgrade (recommended)
helm upgrade --install webapp-3tier ./helm/webapp-3tier -n webapp --create-namespace
```

### Configuration Override
```bash
# Override values via command line
helm upgrade --install webapp-3tier ./helm/webapp-3tier \
  --set replicaCount=5 \
  --set image.tag=v2.0.0 \
  --set autoscaling.enabled=false

# Use custom values file
helm upgrade --install webapp-3tier ./helm/webapp-3tier \
  -f custom-values.yaml
```

### Management Commands
```bash
# List releases
helm list -n webapp

# Get release status
helm status webapp-3tier -n webapp

# Get release values
helm get values webapp-3tier -n webapp

# Rollback to previous version
helm rollback webapp-3tier 1 -n webapp

# Uninstall release
helm uninstall webapp-3tier -n webapp
```

## 📊 Custom Values Examples

### Development Environment
```yaml
# dev-values.yaml
replicaCount: 1
environment: "development"

resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "250m"

autoscaling:
  enabled: false

ingress:
  enabled: false
```

### Production Environment
```yaml
# prod-values.yaml
replicaCount: 5
environment: "production"

resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "1000m"

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 60

ingress:
  enabled: true
  annotations:
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
```

### Staging Environment
```yaml
# staging-values.yaml
replicaCount: 2
environment: "staging"

ingress:
  hosts:
    - host: staging.webapp.example.com
      paths:
        - path: /
          pathType: Prefix

monitoring:
  serviceMonitor:
    enabled: true
    labels:
      environment: staging
```

## 🔍 Troubleshooting

### Check Helm Release
```bash
# Check release status
helm status webapp-3tier -n webapp

# Check release history
helm history webapp-3tier -n webapp

# Get all values (including defaults)
helm get values webapp-3tier -n webapp --all
```

### Debug Template Rendering
```bash
# Dry run to see generated manifests
helm upgrade --install webapp-3tier ./helm/webapp-3tier \
  --dry-run --debug -n webapp

# Template without installing
helm template webapp-3tier ./helm/webapp-3tier \
  --set image.tag=debug
```

### Common Issues

#### 1. Image Pull Errors
```bash
# Check if ECR repository exists
aws ecr describe-repositories --repository-names webapp-3tier-app

# Verify image exists
aws ecr list-images --repository-name webapp-3tier-app
```

#### 2. Service Account Issues
```bash
# Check service account
kubectl get serviceaccount webapp-service-account -n webapp

# Verify IAM role annotation
kubectl describe serviceaccount webapp-service-account -n webapp
```

#### 3. Ingress Issues
```bash
# Check ingress status
kubectl describe ingress webapp-3tier -n webapp

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## 🎯 Best Practices

### 1. Use Specific Image Tags
```yaml
# Good
image:
  tag: "v1.2.3"

# Avoid in production
image:
  tag: "latest"
```

### 2. Set Resource Limits
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

### 3. Enable Health Checks
```yaml
healthCheck:
  enabled: true
  path: "/health"
  initialDelaySeconds: 30

readinessProbe:
  enabled: true
  path: "/health"
  initialDelaySeconds: 5
```

### 4. Use Environment-Specific Values
```bash
# Development
helm upgrade --install webapp-3tier ./helm/webapp-3tier -f dev-values.yaml

# Production
helm upgrade --install webapp-3tier ./helm/webapp-3tier -f prod-values.yaml
```

### 5. Version Your Releases
```bash
# Tag releases
helm upgrade --install webapp-3tier ./helm/webapp-3tier \
  --set image.tag="v1.2.3" \
  --version 1.2.3
```

## 🔄 CI/CD Integration

The GitHub Actions workflow automatically uses Helm for deployment:

```yaml
- name: Deploy with Helm
  run: |
    helm upgrade --install webapp-3tier ./helm/webapp-3tier \
      --namespace webapp \
      --create-namespace \
      --set image.repository="${{ needs.deploy-infrastructure.outputs.ecr-repository }}" \
      --set image.tag="${{ github.sha }}" \
      --wait --timeout=300s
```

## 📚 Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
