#!/usr/bin/env bash
# ==============================================================================
# MedInsight AI — Complete AWS Deployment Script
# Architecture: AWS Amplify (Frontend) -> ALB -> ECS Fargate (FastAPI + ML Model)
# ==============================================================================

set -e

STACK_NAME="medinsight-production"
ECR_REPO_NAME="medinsight-backend"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "================================================================="
echo "🏥 Starting MedInsight AI AWS ECS Fargate + ALB Deployment"
echo "Region: $AWS_REGION | Stack: $STACK_NAME"
echo "================================================================="

# 1. Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"

echo "🔑 AWS Account ID: $AWS_ACCOUNT_ID"
echo "📦 ECR URI: $ECR_URI"

# 2. Create ECR Repository if it doesn't exist
echo "🛠️ Ensuring ECR Repository exists..."
aws ecr describe-repositories --repository-names "$ECR_REPO_NAME" --region "$AWS_REGION" &> /dev/null || \
aws ecr create-repository --repository-name "$ECR_REPO_NAME" --region "$AWS_REGION" --image-scanning-configuration scanOnPush=true

# 3. Authenticate Docker with ECR
echo "🔐 Authenticating Docker to AWS ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 4. Build and Push Backend Docker Image
echo "🐳 Building FastAPI + ML Model Docker image..."
docker build -t "$ECR_REPO_NAME:latest" -f backend/Dockerfile backend/

echo "🚀 Tagging and pushing Docker image to ECR..."
docker tag "$ECR_REPO_NAME:latest" "$ECR_URI"
docker push "$ECR_URI"

# 5. Query Default VPC and Subnets
echo "🌐 Discovering Default VPC and Subnet configuration..."
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION")
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${DEFAULT_VPC_ID}" --query "Subnets[0:2].SubnetId" --output text --region "$AWS_REGION" | tr '\t' ',')

echo "📍 Using VPC: $DEFAULT_VPC_ID"
echo "📍 Using Subnets: $SUBNET_IDS"

# 6. Deploy CloudFormation Stack (ALB + ECS Fargate)
echo "☁️ Deploying CloudFormation Stack (ALB, Target Group, ECS Fargate Service)..."
aws cloudformation deploy \
    --template-file aws/cloudformation-fargate-alb.yml \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        ContainerImageUri="$ECR_URI" \
        VpcId="$DEFAULT_VPC_ID" \
        SubnetIds="$SUBNET_IDS" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$AWS_REGION"

# 7. Get ALB Public DNS Name
ALB_DNS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" --output text --region "$AWS_REGION")

echo "================================================================="
echo "✅ ECS Fargate + ALB Deployment Complete!"
echo "🌐 Application Load Balancer DNS: http://$ALB_DNS"
echo "📚 Swagger API Documentation: http://$ALB_DNS/docs"
echo "🔗 Frontend VITE_API_BASE_URL: http://$ALB_DNS/api"
echo "================================================================="
echo "👉 Next Step: Deploy React Frontend to AWS Amplify with:"
echo "   VITE_API_BASE_URL = http://$ALB_DNS/api"
echo "================================================================="
