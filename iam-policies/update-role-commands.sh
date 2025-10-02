#!/bin/bash

# Commands to update the githubactionagenticai role with EKS Terraform permissions
# Run these commands with appropriate AWS credentials

ROLE_NAME="githubactionagenticai"
POLICY_NAME="EKSTerraformDeploymentPolicy"

echo "🔧 Updating IAM role: $ROLE_NAME"
echo "📋 Policy name: $POLICY_NAME"
echo ""

# Step 1: Create the IAM policy
echo "1️⃣ Creating IAM policy..."
aws iam create-policy \
    --policy-name $POLICY_NAME \
    --policy-document file://eks-terraform-policy.json \
    --description "Comprehensive policy for EKS Terraform deployment including all required AWS services"

# Get the policy ARN (you'll need to replace ACCOUNT_ID with your actual account ID)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo ""
echo "2️⃣ Policy ARN: $POLICY_ARN"
echo ""

# Step 2: Attach the policy to the role
echo "3️⃣ Attaching policy to role..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN

echo ""
echo "✅ Role update completed!"
echo ""
echo "📊 Verify the attachment:"
echo "aws iam list-attached-role-policies --role-name $ROLE_NAME"
echo ""
echo "🔍 Check role details:"
echo "aws iam get-role --role-name $ROLE_NAME"
echo ""

# Alternative: If you prefer to use managed policies instead
echo "🔄 Alternative: Attach AWS managed policies (if preferred):"
echo ""
echo "# EKS Full Access"
echo "aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
echo ""
echo "# EC2 Full Access"
echo "aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess"
echo ""
echo "# IAM Full Access"
echo "aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess"
echo ""
echo "# RDS Full Access"
echo "aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRDSFullAccess"
echo ""
echo "# API Gateway Administrator"
echo "aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator"
echo ""
echo "# ECR Full Access"
echo "aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
