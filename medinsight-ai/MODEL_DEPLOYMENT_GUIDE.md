# 🧠 Machine Learning Model Deployment Guide — MedInsight AI

This guide explains how the **Readmission Risk Prediction ML Pipeline** (XGBoost + LightGBM Ensemble + Isotonic Calibration + SHAP Explainers) is deployed and served in production on AWS and cloud environments.

---

## 🏗️ ML Model Architecture & Artifacts

The ML system consists of 6 artifact files located in `backend/app/ml/artifacts/`:

| Artifact | File | Purpose | Size |
|---|---|---|---|
| **Preprocessor** | `preprocessor.joblib` | Scikit-learn Pipeline (StandardScaler + OneHotEncoder) | ~6 KB |
| **XGBoost Final** | `xgboost_final.joblib` | Trained XGBoost Gradient Boosted Trees Classifier | ~748 KB |
| **LightGBM Final** | `lightgbm_final.joblib` | Trained LightGBM GBDT Classifier | ~1.05 MB |
| **Isotonic Calibrator (XGB)**| `isotonic_xgb.joblib` | Probability calibrator for XGBoost outputs | ~1.1 KB |
| **Isotonic Calibrator (LGB)**| `isotonic_lgb.joblib` | Probability calibrator for LightGBM outputs | ~1.5 KB |
| **Model Metadata** | `metadata.json` | Feature schema, OHE columns, decision threshold, weights | ~5 KB |

---

## ⚡ Deployment Methods for Models

### 1. In-Container FastAPI Serving (Default & Recommended for AWS EC2)

In this approach, the models are embedded directly inside the backend container and loaded into memory on server boot:

```mermaid
flowchart LR
    subgraph FastAPI_Process["FastAPI Process (Memory)"]
        ML_LOADER[model_loader.py (Singleton)]
        PREP[Preprocessor Transformer]
        ENS[XGBoost + LightGBM Ensemble]
        SHAP[SHAP TreeExplainer]
        CALIB[Isotonic Calibrator]
    end

    EHR_REQ[Incoming Patient Data] --> ML_LOADER
    ML_LOADER --> PREP
    PREP --> ENS
    ENS --> CALIB
    CALIB --> Output[Calibrated Risk Score + Level]
    ENS --> SHAP
    SHAP --> Explanations[Feature Contributions]
```

**Benefits:**
- **Zero Network Latency:** Inference runs locally in memory (< 25ms per prediction).
- **Zero Extra Cost:** Runs within the existing EC2 / Docker container.
- **Explainability:** SHAP feature importance is calculated on-the-fly.

---

### 2. Updating / Retraining Models in Production

To train a new version of the model on the latest dataset:

1. Place updated `diabetic_data.csv` in the root folder.
2. Run the training pipeline:
   ```bash
   cd medinsight-ai/backend
   python app/ml/train_and_export.py
   ```
3. The new artifacts (`.joblib` & `metadata.json`) are automatically generated in `app/ml/artifacts/`.
4. Commit and push to Git, or rebuild the Docker container on AWS:
   ```bash
   sudo docker compose -f docker-compose.aws.yml up -d --build
   ```

---

### 3. Dedicated AWS SageMaker Real-Time Endpoint (Enterprise Scale)

If you require separate auto-scaling inference endpoints:

1. **Upload model artifacts to Amazon S3:**
   ```bash
   tar -czvf model.tar.gz -C backend/app/ml/artifacts .
   aws s3 cp model.tar.gz s3://your-medinsight-bucket/models/v2/model.tar.gz
   ```

2. **Create SageMaker Model & Endpoint:**
   - Framework: Scikit-learn / XGBoost pre-built container.
   - Instance Type: `ml.t2.medium` or `ml.m5.large`.
   - Point your backend environment variable `SAGEMAKER_ENDPOINT_NAME=medinsight-readmission-endpoint`.

---

### 4. S3 Dynamic Model Loading (Zero Downtime Hot-Reload)

To update models without rebuilding Docker images:

1. Store `.joblib` files in an S3 bucket: `s3://medinsight-models/artifacts/`.
2. Configure EC2 IAM Role with S3 Read permissions.
3. Add a startup sync in your container or deploy script:
   ```bash
   aws s3 sync s3://medinsight-models/artifacts/ /app/app/ml/artifacts/
   ```
4. Call `POST /api/system/reload-model` to hot-swap the loaded model in memory without server restarts.

---

## 📊 Performance & Inference Benchmarks

| Metric | Measured Value |
|---|---|
| **Cold Start Load Time** | ~450 ms |
| **Warm Inference Latency** | **12 - 25 ms** |
| **SHAP Explanation Latency** | **35 - 55 ms** |
| **RAM Footprint in Docker** | **~320 MB** (fits easily in AWS `t2.micro` / `t3.micro`) |
| **Throughput (Single Worker)** | ~80 requests/sec |
