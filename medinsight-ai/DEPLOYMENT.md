# 🚀 MedInsight AI — Cloud Deployment Guide

This guide provides step-by-step instructions for deploying the **MedInsight AI** full-stack application (FastAPI + Machine Learning + React/Vite + MongoDB Atlas) to the cloud.

---

## 📋 Architecture Overview

- **Database:** MongoDB Atlas (Cloud Managed NoSQL)
- **Backend:** FastAPI + Scikit-Learn/XGBoost/SHAP ML Pipeline (Python 3.11)
- **Frontend:** React + Vite + TailwindCSS + Lucide Icons
- **AI Engine:** Google Gemini AI (via `google-genai` / REST)

---

## 🌟 Method 1: Render + Vercel (Recommended — Free & Easy)

This is the most cost-effective, straightforward setup for hackathons and live demos.

### Step 1: Ensure MongoDB Atlas is Configured
1. Go to [MongoDB Atlas](https://www.mongodb.com/cloud/atlas).
2. Ensure your Cluster has Network Access configured to **Allow Access from Anywhere (`0.0.0.0/0`)** so cloud servers can connect.
3. Your database connection string is ready:
   ```text
   mongodb+srv://<username>:<password>@cognizant.mhj2q40.mongodb.net/?appName=Cognizant
   ```

---

### Step 2: Deploy Backend to [Render.com](https://render.com)
1. Push your repository to **GitHub**.
2. Log in to [Render Dashboard](https://dashboard.render.com/) and click **New +** ➔ **Web Service**.
3. Select your GitHub repository.
4. Fill in the configuration:
   - **Name:** `medinsight-backend`
   - **Root Directory:** `medinsight-ai/backend` (or `backend` if repo root is `medinsight-ai`)
   - **Runtime:** `Python 3`
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type:** `Free` or `Starter`
5. Under **Environment Variables**, add:
   | Key | Value |
   |---|---|
   | `MONGODB_URL` | `mongodb+srv://Roshan2106:1234@cognizant.mhj2q40.mongodb.net/?appName=Cognizant` |
   | `MONGODB_DB_NAME` | `medinsight_db` |
   | `JWT_SECRET_KEY` | `your-secure-jwt-secret-at-least-32-characters-long` |
   | `JWT_ALGORITHM` | `HS256` |
   | `ACCESS_TOKEN_EXPIRE_MINUTES` | `480` |
   | `ML_MODEL_PATH` | `app/ml/artifacts/model.joblib` |
   | `ML_MODEL_TYPE` | `ensemble` |
   | `CORS_ORIGINS` | `*` (or your frontend Vercel URL) |
   | `GENAI_PROVIDER` | `gemini` |
   | `GENAI_API_KEY` | *(Your Google Gemini API Key)* |
   | `GENAI_MODEL` | `gemini-1.5-flash` |
6. Click **Create Web Service**.
7. Once deployed, note down your backend URL (e.g., `https://medinsight-backend.onrender.com`).
8. Test by visiting `https://medinsight-backend.onrender.com/docs` in your browser.

---

### Step 3: Deploy Frontend to [Vercel](https://vercel.com)
1. Go to [Vercel Dashboard](https://vercel.com/dashboard) and click **Add New...** ➔ **Project**.
2. Import your GitHub repository.
3. Configure the Project:
   - **Framework Preset:** `Vite`
   - **Root Directory:** Edit and choose `medinsight-ai/frontend` (or `frontend`).
   - **Build Command:** `npm run build`
   - **Output Directory:** `dist`
4. Under **Environment Variables**, add:
   | Key | Value |
   |---|---|
   | `VITE_API_BASE_URL` | `https://medinsight-backend.onrender.com/api` |
   *(Replace with your actual Render backend URL followed by `/api`)*
5. Click **Deploy**.
6. When complete, your web app is live worldwide with HTTPS!

---

## 🚂 Method 2: Railway.app (One-Click Full Stack)

1. Go to [Railway.app](https://railway.app) and create a **New Project** from your GitHub repo.
2. Add Service ➔ **Backend**:
   - Set Root Directory: `/medinsight-ai/backend`
   - Add the environment variables from the table above.
   - Railway will automatically detect the `Dockerfile` or Python runtime and assign a public domain.
3. Add Service ➔ **Frontend**:
   - Set Root Directory: `/medinsight-ai/frontend`
   - Set `VITE_API_BASE_URL` to your Railway backend public URL + `/api`.
   - Railway will build and serve the static files or container.

---

## 🐳 Method 3: AWS EC2 / DigitalOcean / GCP Compute Engine (Docker Compose)

If you have a Linux VM (Ubuntu):

1. **SSH into your server:**
   ```bash
   ssh ubuntu@<your-server-ip>
   ```

2. **Install Docker & Docker Compose:**
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose git
   sudo systemctl enable --now docker
   ```

3. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd cognizant/medinsight-ai
   ```

4. **Configure Environment:**
   Create `.env` inside `backend/`:
   ```bash
   MONGODB_URL=mongodb+srv://Roshan2106:1234@cognizant.mhj2q40.mongodb.net/?appName=Cognizant
   JWT_SECRET_KEY=super-secret-key-32-chars-long
   CORS_ORIGINS=*
   GENAI_API_KEY=your_gemini_api_key
   ```

5. **Run Docker Compose:**
   ```bash
   docker-compose up -d --build
   ```

6. Access your app at `http://<your-server-ip>:5173` and API at `http://<your-server-ip>:8000/docs`.

---

## 🧪 Post-Deployment Verification Checklist

- [ ] **Database Connection:** Backend logs show `MedInsight AI MongoDB database initialized and verified.`
- [ ] **API Swagger UI:** Access `<backend-url>/docs` and check all endpoints respond.
- [ ] **Login / Registration:** Register a new clinician account and login.
- [ ] **Readmission Prediction:** Run an AI prediction test for a patient.
- [ ] **Clinical Copilot:** Ask a query to verify Gemini GenAI response.
- [ ] **SPA Routing:** Refreshing pages like `/patients` or `/predict` loads properly without 404 errors (handled by `vercel.json` / `nginx.conf`).
