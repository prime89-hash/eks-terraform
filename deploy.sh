#!/bin/bash

set -e

echo "🚀 Starting 3-Tier Web Application Deployment on EKS"

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-west-2}

echo "🔧 AWS Account: $AWS_ACCOUNT_ID"
echo "🌍 AWS Region: $AWS_REGION"

# Create terraform.tfvars if it doesn't exist
if [ ! -f terraform.tfvars ]; then
    echo "📝 Creating terraform.tfvars from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "⚠️  Please update terraform.tfvars with your specific values before continuing."
    echo "   Especially update the domain_name and db_password variables."
    read -p "Press Enter to continue after updating terraform.tfvars..."
fi

# Initialize and apply Terraform
echo "🏗️ Initializing Terraform..."
terraform init

echo "📋 Planning Terraform deployment..."
terraform plan -var="environment=prod"

echo "🚀 Applying Terraform configuration..."
terraform apply -auto-approve -var="environment=prod"

# Get outputs
echo "📊 Getting deployment outputs..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

echo "✅ Infrastructure deployed successfully!"
echo ""
echo "📊 Deployment Information:"
echo "🔗 EKS Cluster: $CLUSTER_NAME"
echo "📦 ECR Repository: $ECR_REPOSITORY_URL"
echo "🗄️ RDS Endpoint: $RDS_ENDPOINT"
echo ""

# Update kubeconfig
echo "⚙️ Updating kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Wait for cluster to be ready
echo "⏳ Waiting for EKS cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Build and push Docker image
echo "🐳 Building and pushing Docker image..."
cd app

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build image
docker build -t webapp-3tier .
docker tag webapp-3tier:latest $ECR_REPOSITORY_URL:latest
docker push $ECR_REPOSITORY_URL:latest

cd ..

# Update Kubernetes manifests
echo "📝 Updating Kubernetes manifests..."
sed -i.bak "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" k8s/deployment.yaml
sed -i.bak "s|ACCOUNT_ID|$AWS_ACCOUNT_ID|g" k8s/ingress.yaml

# Encode RDS endpoint for secret
RDS_ENDPOINT_B64=$(echo -n "$RDS_ENDPOINT" | base64)
sed -i.bak "s|db-host: # Base64 encoded RDS endpoint|db-host: $RDS_ENDPOINT_B64|g" k8s/deployment.yaml

# Get certificate ARN and security group ID
CERTIFICATE_ARN=$(terraform output -raw certificate_arn)
ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=webapp-3tier-alb-*" --query 'SecurityGroups[0].GroupId' --output text)
PUBLIC_SUBNET_IDS=$(terraform output -json public_subnets | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

sed -i.bak "s|CERTIFICATE_ARN|$CERTIFICATE_ARN|g" k8s/ingress.yaml
sed -i.bak "s|ALB_SECURITY_GROUP_ID|$ALB_SG_ID|g" k8s/ingress.yaml
sed -i.bak "s|PUBLIC_SUBNET_IDS|$PUBLIC_SUBNET_IDS|g" k8s/ingress.yaml

# Get deployment values
echo "📊 Getting deployment values..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
CERTIFICATE_ARN=$(terraform output -raw certificate_arn)
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Create Kubernetes secret
echo "🔐 Creating Kubernetes secrets..."
kubectl create secret generic webapp-secrets -n webapp \
  --from-literal=db-host="$RDS_ENDPOINT" \
  --from-literal=db-name="webapp" \
  --from-literal=db-username="webapp_user" \
  --from-literal=db-password="YourSecurePassword123!" \
  --dry-run=client -o yaml | kubectl apply -f -

# Deploy with Helm
echo "⚓ Deploying application with Helm..."
helm upgrade --install webapp-3tier ./helm/webapp-3tier \
  --namespace webapp \
  --create-namespace \
  --set image.repository="$ECR_REPO" \
  --set image.tag="latest" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::$ACCOUNT_ID:role/webapp-3tier-pod-role" \
  --set ingress.annotations."alb\.ingress\.kubernetes\.io/certificate-arn"="$CERTIFICATE_ARN" \
  --wait --timeout=300s

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/webapp-3tier -n webapp --timeout=300s

# Get load balancer DNS
echo "⏳ Waiting for load balancer to be provisioned..."
sleep 60

ALB_DNS=$(kubectl get ingress webapp-ingress -n webapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📊 Access Information:"
echo "🌐 Application URL: https://$ALB_DNS"
echo "🏥 Health Check: https://$ALB_DNS/health"
echo "📈 Metrics: https://$ALB_DNS/actuator/prometheus"
echo ""
echo "🔧 Management Commands:"
echo "kubectl get pods -n webapp"
echo "kubectl logs -n webapp deployment/webapp-3tier"
echo "kubectl describe ingress -n webapp webapp-ingress"
echo ""
echo "📚 Next Steps:"
echo "1. Update your DNS to point to the ALB: $ALB_DNS"
echo "2. Access Grafana for monitoring: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "3. Monitor application logs: kubectl logs -f -n webapp deployment/webapp-3tier"
echo ""
echo "💡 To destroy the infrastructure: terraform destroy -auto-approve -var=\"environment=prod\""
