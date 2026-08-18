# 🚀 AWS Architecture Deployment Guide — MedInsight AI

This guide documents the enterprise deployment architecture on **Amazon Web Services (AWS)** using **AWS Amplify**, **Application Load Balancer (ALB)**, and **Amazon ECS Fargate** with the trained Machine Learning model.

---

## 🏛️ Target System Architecture

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

## 📂 Architecture Artifacts & Templates

| File | Description |
|---|---|
| [`frontend/amplify.yml`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/frontend/amplify.yml) | Build specification & security headers for **AWS Amplify Hosting**. |
| [`aws/cloudformation-fargate-alb.yml`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/aws/cloudformation-fargate-alb.yml) | CloudFormation template creating ALB, Target Group, ECS Cluster, Task Definition & Fargate Service. |
| [`aws/ecs-task-definition.json`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/aws/ecs-task-definition.json) | Container task definition with ML model artifacts, MongoDB Atlas URI, and environment variables. |
| [`aws/deploy-to-aws.sh`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/aws/deploy-to-aws.sh) | Automated Linux/macOS Bash deployment script. |
| [`aws/deploy-to-aws.ps1`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/aws/deploy-to-aws.ps1) | Automated Windows PowerShell deployment script. |

---

## 🛠️ Step 1: Deploy Backend to AWS ECR, ECS Fargate & ALB

### Prerequisites:
- [AWS CLI](https://aws.amazon.com/cli/) installed and configured (`aws configure`).
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) running locally.

### 1-Command Automated Deploy:
Open your terminal in `medinsight-ai/`:

**On Windows (PowerShell):**
```powershell
.\aws\deploy-to-aws.ps1
```

**On Linux / Mac (Bash):**
```bash
chmod +x aws/deploy-to-aws.sh
./aws/deploy-to-aws.sh
```

### What this automated script does:
1. Creates an **Amazon ECR** repository named `medinsight-backend`.
2. Builds the Docker container containing FastAPI + ML model artifacts (`xgboost_final.joblib`, `lightgbm_final.joblib`, `preprocessor.joblib`, `metadata.json`).
3. Pushes the Docker image to your private Amazon ECR registry.
4. Deploys the CloudFormation stack:
   - Sets up the **Application Load Balancer (ALB)** with health checks at `/`.
   - Provisions the **ECS Fargate** cluster and service (1 vCPU, 2GB RAM).
   - Configures Security Groups allowing port 80/443 on ALB and forwarding to port 8000 on ECS.
5. Outputs your **Application Load Balancer DNS** (e.g. `http://medinsight-production-alb-123456789.us-east-1.elb.amazonaws.com`).

---

## 🌐 Step 2: Deploy React Frontend to AWS Amplify

1. Log into the **[AWS Amplify Console](https://console.aws.amazon.com/amplify/)**.
2. Click **Create new app** ➔ Select **GitHub** (or your Git provider).
3. Select your repository and the `main` branch.
4. In the **App settings**:
   - **App name:** `medinsight-ai`
   - **Monorepo / Root directory:** Set to `medinsight-ai/frontend` (or `frontend`).
5. In **Build and test settings**, Amplify will automatically detect the [`frontend/amplify.yml`](file:///c:/Users/user/OneDrive/Desktop/Cognizant%20-hackathon/cognizant/medinsight-ai/frontend/amplify.yml) file.
6. Under **Advanced settings ➔ Environment variables**, add:
   | Key | Value |
   |---|---|
   | `VITE_API_BASE_URL` | `http://<YOUR-ALB-DNS-NAME>/api` |
7. Under **App settings ➔ Rewrites and redirects**, ensure the Single Page Application rule is present:
   - **Source address:** `</^[^.]+$|\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|woff2|ttf|map|json)$)([^.]+$)/>`
   - **Target address:** `/index.html`
   - **Type:** `200 (Rewrite)`
8. Click **Save and deploy**.

Amplify will automatically build, test, and deploy the React frontend globally on AWS CloudFront edge servers with SSL.

---

## 🔄 Updating Models or Code

- **To update Backend / ML Models:**
  Re-run `.\aws\deploy-to-aws.ps1`. ECS Fargate will perform a rolling zero-downtime deployment.
- **To update Frontend:**
  Push your commits to GitHub. AWS Amplify will automatically detect changes, build, and deploy the new version.
