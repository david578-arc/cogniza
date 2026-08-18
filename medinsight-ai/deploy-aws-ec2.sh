#!/usr/bin/env bash
# ==============================================================================
# MedInsight AI — AWS EC2 Automated Deployment Script
# Supports: Ubuntu 20.04 / 22.04 / 24.04 LTS on AWS EC2
# ==============================================================================

set -e

echo "========================================================="
echo "🏥 Starting MedInsight AI AWS EC2 Production Deployment"
echo "========================================================="

# 1. Update system packages
echo "📦 Updating system packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

# 2. Install prerequisites and Docker
echo "🐳 Installing Docker & Docker Compose..."
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER"
    rm get-docker.sh
fi

# Ensure docker compose plugin exists
sudo apt-get install -y docker-compose-plugin

# 3. Setup Swap space for smooth ML operation on t2.micro/t3.micro instances
if [ ! -f /swapfile ]; then
    echo "🧠 Configuring 2GB Swap Memory for ML model safety on EC2 micro instances..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# 4. Check for .env file or create default
if [ ! -f .env ]; then
    echo "⚙️ Creating default .env file..."
    cat << 'EOF' > .env
MONGODB_URL=mongodb+srv://Roshan2106:1234@cognizant.mhj2q40.mongodb.net/?appName=Cognizant
MONGODB_DB_NAME=medinsight_db
JWT_SECRET_KEY=medinsight-production-secure-jwt-key-2026-hackathon
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=480
ML_MODEL_PATH=app/ml/artifacts/model.joblib
ML_MODEL_TYPE=ensemble
CORS_ORIGINS=*
GENAI_PROVIDER=gemini
GENAI_MODEL=gemini-1.5-flash
GENAI_API_KEY=
EOF
    echo "⚠️ Note: You can edit the .env file anytime to update your GENAI_API_KEY!"
fi

# 5. Build and launch with Docker Compose
echo "🚀 Building and launching containers on Port 80..."
sudo docker compose -f docker-compose.aws.yml up -d --build

echo "========================================================="
echo "✅ MedInsight AI is now running on AWS EC2!"
echo "🌐 Web App URL: http://$(curl -s ifconfig.me)"
echo "📚 API Swagger Docs: http://$(curl -s ifconfig.me)/docs"
echo "========================================================="
