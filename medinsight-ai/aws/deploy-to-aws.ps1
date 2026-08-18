# ==============================================================================
# MedInsight AI — AWS ECS Fargate + ALB PowerShell Deployment Script
# Architecture: AWS Amplify (Frontend) -> ALB -> ECS Fargate (FastAPI + ML Model)
# ==============================================================================

$ErrorActionPreference = "Stop"

$STACK_NAME = "medinsight-production"
$ECR_REPO_NAME = "medinsight-backend"
$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "us-east-1" }

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "🏥 Starting MedInsight AI AWS ECS Fargate + ALB Deployment" -ForegroundColor Cyan
Write-Host "Region: $AWS_REGION | Stack: $STACK_NAME" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Preflight Check: AWS CLI
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Host "`n❌ Error: AWS CLI is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "👉 Quick Install: Run the following command in PowerShell (Admin):" -ForegroundColor Yellow
    Write-Host "   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi" -ForegroundColor Cyan
    Write-Host "   Then restart PowerShell and run: aws configure" -ForegroundColor Cyan
    Write-Host "`n💡 Alternatively: Use AWS CloudShell (in browser) where AWS CLI & Docker are pre-installed!" -ForegroundColor Green
    Exit 1
}

# Preflight Check: Docker
if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
    Write-Host "`n❌ Error: Docker is not installed or Docker Desktop is not running." -ForegroundColor Red
    Write-Host "👉 Please start Docker Desktop and try again." -ForegroundColor Yellow
    Exit 1
}

# 1. Check AWS CLI and Identity
Write-Host "🔍 Verifying AWS CLI authentication..." -ForegroundColor Yellow
try {
    $AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text).Trim()
} catch {
    Write-Host "`n❌ AWS credentials not configured. Please run: aws configure" -ForegroundColor Red
    Exit 1
}
$ECR_URI = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/${ECR_REPO_NAME}:latest"

Write-Host "🔑 AWS Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Green
Write-Host "📦 ECR URI: $ECR_URI" -ForegroundColor Green

# 2. Ensure ECR Repository
Write-Host "🛠️ Ensuring ECR repository exists..." -ForegroundColor Yellow
try {
    aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION | Out-Null
} catch {
    Write-Host "Creating repository $ECR_REPO_NAME..." -ForegroundColor Yellow
    aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --image-scanning-configuration scanOnPush=true | Out-Null
}

# 3. Login Docker to ECR
Write-Host "🔐 Authenticating Docker to AWS ECR..." -ForegroundColor Yellow
$password = aws ecr get-login-password --region $AWS_REGION
$password | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# 4. Build and Push Docker image
Write-Host "🐳 Building Docker image for FastAPI + ML Pipeline..." -ForegroundColor Yellow
docker build -t "$ECR_REPO_NAME:latest" -f backend/Dockerfile backend/

Write-Host "🚀 Tagging and pushing Docker image to ECR..." -ForegroundColor Yellow
docker tag "$ECR_REPO_NAME:latest" $ECR_URI
docker push $ECR_URI

# 5. Query VPC and Subnets
Write-Host "🌐 Discovering Default VPC and Subnets..." -ForegroundColor Yellow
$DEFAULT_VPC_ID = (aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $AWS_REGION).Trim()
$SUBNET_LIST = (aws ec2 describe-subnets --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" --query "Subnets[0:2].SubnetId" --output text --region $AWS_REGION).Trim().Split("`t") -join ","

Write-Host "📍 Using VPC: $DEFAULT_VPC_ID" -ForegroundColor Green
Write-Host "📍 Using Subnets: $SUBNET_LIST" -ForegroundColor Green

# 6. Deploy CloudFormation Stack
Write-Host "☁️ Deploying CloudFormation Stack (ALB + Target Group + ECS Fargate)..." -ForegroundColor Yellow
aws cloudformation deploy `
    --template-file aws/cloudformation-fargate-alb.yml `
    --stack-name $STACK_NAME `
    --parameter-overrides `
        ContainerImageUri="$ECR_URI" `
        VpcId="$DEFAULT_VPC_ID" `
        SubnetIds="$SUBNET_LIST" `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $AWS_REGION

# 7. Query Output ALB DNS
$ALB_DNS = (aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='AlbDnsName'].OutputValue" --output text --region $AWS_REGION).Trim()

Write-Host "=================================================================" -ForegroundColor Green
Write-Host "✅ ECS Fargate + ALB Deployment Succeeded!" -ForegroundColor Green
Write-Host "🌐 Application Load Balancer DNS: http://$ALB_DNS" -ForegroundColor Cyan
Write-Host "📚 Swagger API Docs: http://$ALB_DNS/docs" -ForegroundColor Cyan
Write-Host "🔗 Backend API Base URL: http://$ALB_DNS/api" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "👉 In AWS Amplify Console, set environment variable:" -ForegroundColor Yellow
Write-Host "   VITE_API_BASE_URL = http://$ALB_DNS/api" -ForegroundColor Yellow
Write-Host "=================================================================" -ForegroundColor Green
