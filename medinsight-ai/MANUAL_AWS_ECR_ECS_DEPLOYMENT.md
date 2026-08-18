# 🖱️ Manual AWS Console Deployment Guide — ECR + ECS Fargate + ALB + Amplify

This guide walks you step-by-step through setting up the complete architecture manually using the **AWS Web Management Console (GUI)**.

```text
                 USER
                  │
                  ▼
        ┌──────────────────┐
        │  React Frontend  │
        │  AWS Amplify     │
        └────────┬─────────┘
                 │
                 │ HTTPS
                 ▼
        ┌──────────────────┐
        │ Application      │
        │ Load Balancer    │
        └────────┬─────────┘
                 │
                 ▼
        ┌──────────────────┐
        │ ECS Fargate      │
        │                  │
        │ FastAPI          │
        │      +           │
        │ model.joblib     │
        └────────┬─────────┘
                 │
                 ▼
             Prediction
```

---

## 📦 PART 1: Create Amazon ECR Repository & Push Image

### 1.1 Create the ECR Repository in AWS Console
1. In the AWS Console search bar, type **ECR** and select **Elastic Container Registry**.
2. Click **Create repository**.
3. Configure repository:
   - **Visibility settings:** `Private`
   - **Repository name:** `medinsight-backend`
   - **Tag immutability:** `Disabled`
   - **Scan on push:** `Enabled`
4. Click **Create repository**.
5. Copy your **Repository URI** (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com/medinsight-backend`).

---

### 1.2 Push Docker Image to ECR (Using AWS Console "View Push Commands")
1. Click on your `medinsight-backend` repository.
2. Click the **View push commands** button in the top right.
3. Run the 4 commands shown in your terminal from the `medinsight-ai` directory:

```bash
# 1. Login to ECR (replace with your account ID and region)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <YOUR-ACCOUNT-ID>.dkr.ecr.us-east-1.amazonaws.com

# 2. Build the Docker Image
docker build -t medinsight-backend -f backend/Dockerfile backend/

# 3. Tag the image
docker tag medinsight-backend:latest <YOUR-ACCOUNT-ID>.dkr.ecr.us-east-1.amazonaws.com/medinsight-backend:latest

# 4. Push to ECR
docker push <YOUR-ACCOUNT-ID>.dkr.ecr.us-east-1.amazonaws.com/medinsight-backend:latest
```

---

## ⚖️ PART 2: Create Application Load Balancer (ALB) & Target Group

### 2.1 Create Target Group
1. In the AWS Console, navigate to **EC2** ➔ Under **Load Balancing**, click **Target Groups**.
2. Click **Create target group**.
3. **Basic configuration:**
   - **Target type:** Choose **IP addresses** *(Required for ECS Fargate)*
   - **Target group name:** `medinsight-backend-tg`
   - **Protocol:** `HTTP`
   - **Port:** `8000`
   - **IP address type:** `IPv4`
   - **VPC:** Select your Default VPC
4. **Health checks:**
   - **Health check protocol:** `HTTP`
   - **Health check path:** `/` *(FastAPI root endpoint returns 200 OK)*
5. Click **Next** ➔ Click **Create target group** (skip registering targets for now, ECS will auto-register).

---

### 2.2 Create Application Load Balancer
1. In **EC2 Console** ➔ Click **Load Balancers** ➔ Click **Create load balancer**.
2. Select **Application Load Balancer (ALB)** ➔ Click **Create**.
3. **Basic configuration:**
   - **Load balancer name:** `medinsight-alb`
   - **Scheme:** `Internet-facing`
   - **IP address type:** `IPv4`
4. **Network mapping:**
   - **VPC:** Select your Default VPC.
   - **Mappings (Subnets):** Check at least **2 Availability Zones** (e.g. `us-east-1a`, `us-east-1b`).
5. **Security groups:**
   - Create or select a Security Group allowing **Inbound HTTP (Port 80)** and **HTTPS (Port 443)** from `0.0.0.0/0`.
6. **Listeners and routing:**
   - **Protocol:** `HTTP`
   - **Port:** `80`
   - **Default action:** Select **Forward to** ➔ choose `medinsight-backend-tg`.
7. Click **Create load balancer**.
8. Copy the **DNS name** (e.g., `medinsight-alb-123456789.us-east-1.elb.amazonaws.com`).

---

## 🚀 PART 3: Create Amazon ECS Cluster, Task Definition & Fargate Service

### 3.1 Create ECS Cluster
1. Search for **ECS** and open **Elastic Container Service**.
2. Click **Clusters** ➔ **Create cluster**.
3. **Cluster configuration:**
   - **Cluster name:** `medinsight-cluster`
   - **Infrastructure:** Select **AWS Fargate (serverless)**
4. Click **Create**.

---

### 3.2 Create ECS Task Definition
1. In ECS Console left menu, click **Task definitions** ➔ **Create new task definition** ➔ Choose **Create new task definition with JSON** (or use the UI builder):
2. Paste the following configuration (replace `<YOUR-ACCOUNT-ID>` and `<REGION>`):

```json
{
  "family": "medinsight-backend-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "containerDefinitions": [
    {
      "name": "medinsight-fastapi-ml",
      "image": "<YOUR-ACCOUNT-ID>.dkr.ecr.<REGION>.amazonaws.com/medinsight-backend:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        { "name": "MONGODB_URL", "value": "mongodb+srv://Roshan2106:1234@cognizant.mhj2q40.mongodb.net/?appName=Cognizant" },
        { "name": "MONGODB_DB_NAME", "value": "medinsight_db" },
        { "name": "JWT_SECRET_KEY", "value": "medinsight-production-secure-jwt-key-2026-fargate-alb" },
        { "name": "JWT_ALGORITHM", "value": "HS256" },
        { "name": "ACCESS_TOKEN_EXPIRE_MINUTES", "value": "480" },
        { "name": "ML_MODEL_PATH", "value": "app/ml/artifacts/model.joblib" },
        { "name": "ML_MODEL_TYPE", "value": "ensemble" },
        { "name": "CORS_ORIGINS", "value": "*" },
        { "name": "GENAI_PROVIDER", "value": "gemini" },
        { "name": "GENAI_MODEL", "value": "gemini-1.5-flash" },
        { "name": "GENAI_API_KEY", "value": "" }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-create-group": "true",
          "awslogs-group": "/ecs/medinsight-backend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "fastapi"
        }
      }
    }
  ]
}
```
3. Click **Create**.

---

### 3.3 Create ECS Service (Deploying Fargate with ALB)
1. In ECS Console, open your cluster: **`medinsight-cluster`**.
2. Under the **Services** tab, click **Create**.
3. **Environment:**
   - **Compute configuration:** `Launch type` ➔ **FARGATE**
   - **Deployment configuration:** `Service`
   - **Family:** Choose `medinsight-backend-task` (latest revision).
   - **Service name:** `medinsight-service`
   - **Desired tasks:** `1`
4. **Networking:**
   - **VPC:** Choose your Default VPC.
   - **Subnets:** Select public subnets.
   - **Security group:** Create or select a Security Group that allows **Inbound Port 8000** from your ALB Security Group.
   - **Public IP:** `Turned on`
5. **Load balancing:**
   - **Load balancer type:** Select **Application Load Balancer**.
   - **Load balancer:** Select `medinsight-alb`.
   - **Container:** `medinsight-fastapi-ml 8000:8000`
   - **Target group:** Select **Use an existing target group** ➔ choose `medinsight-backend-tg`.
6. Click **Create**.

*ECS Fargate will now launch the container and register it with the ALB. In 1-2 minutes, test by opening `http://<YOUR-ALB-DNS-NAME>/docs` in your browser!*

---

## 🌐 PART 4: Deploy React Frontend to AWS Amplify

1. Go to the **[AWS Amplify Console](https://console.aws.amazon.com/amplify/)**.
2. Click **Create new app** ➔ Choose **GitHub** (or your Git repository).
3. Authorize and select your repository & `main` branch.
4. **App Settings:**
   - **App name:** `medinsight-ai`
   - Check **Monorepo** and set the root directory to: `medinsight-ai/frontend` (or `frontend`).
5. **Build settings:** Amplify will automatically detect [`frontend/amplify.yml`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/frontend/amplify.yml).
6. **Environment variables:**
   Add the following key-value pair:
   | Variable | Value |
   |---|---|
   | `VITE_API_BASE_URL` | `http://<YOUR-ALB-DNS-NAME>/api` |
7. Click **Save and deploy**.

AWS Amplify builds and publishes your frontend globally with continuous deployment (CI/CD) and HTTPS.
