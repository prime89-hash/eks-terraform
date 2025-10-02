# IAM Role Setup for EKS Terraform Deployment

This directory contains the necessary IAM policies and commands to update the `githubactionagenticai` role for EKS Terraform deployment.

## 🔧 Quick Setup

### Option 1: Run the Update Script
```bash
cd iam-policies
./update-role-commands.sh
```

### Option 2: Manual Commands

#### Step 1: Create Custom Policy
```bash
aws iam create-policy \
    --policy-name EKSTerraformDeploymentPolicy \
    --policy-document file://eks-terraform-policy.json \
    --description "Comprehensive policy for EKS Terraform deployment"
```

#### Step 2: Attach Policy to Role
```bash
# Get your account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Attach the policy
aws iam attach-role-policy \
    --role-name githubactionagenticai \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/EKSTerraformDeploymentPolicy
```

### Option 3: Use AWS Managed Policies (Simpler)
```bash
ROLE_NAME="githubactionagenticai"

# Attach managed policies
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
```

## 📋 Required Permissions

The EKS Terraform deployment requires permissions for:

- **EKS**: Cluster creation and management
- **EC2**: VPC, subnets, security groups, NAT gateways
- **IAM**: Role and policy creation for EKS services
- **RDS**: Database creation and management
- **ECR**: Container registry management
- **ELB**: Application Load Balancer creation
- **API Gateway**: REST API and custom domain setup
- **ACM**: SSL certificate management
- **Route53**: DNS management (if using custom domains)
- **CloudWatch**: Logging and monitoring
- **KMS**: Encryption key management
- **Secrets Manager**: Credential storage
- **WAF**: Web Application Firewall
- **SNS**: Notification services

## 🔍 Verification

After updating the role, verify the permissions:

```bash
# List attached policies
aws iam list-attached-role-policies --role-name githubactionagenticai

# Get role details
aws iam get-role --role-name githubactionagenticai
```

## 🚨 Security Notes

- The provided policy follows the principle of least privilege for EKS deployment
- Consider using AWS managed policies for simpler management
- Review and audit permissions regularly
- Use resource-specific permissions where possible in production

## 🔄 Trust Policy

If you need to update the trust policy for GitHub OIDC, use:

```bash
aws iam update-assume-role-policy \
    --role-name githubactionagenticai \
    --policy-document file://github-oidc-trust-policy.json
```

Make sure to replace `ACCOUNT_ID` in the trust policy with your actual AWS account ID.
