# Pramana – System Design Document

## 1. System Overview

Pramana is a scalable, AI-enabled governance observability platform designed to support multi-level government structures and cross-department deployment.

Architecture Layers:
- Client Layer
- API Gateway
- Backend Services
- Data Layer
- AI/ML Layer
- Aggregation & Data Warehouse
- Security Layer

---

## 2. High-Level Architecture

### Client Layer
- Web Dashboard (React.js)
- Mobile App (Android / React Native)

### API Layer
- REST API Gateway
- Authentication & Routing

### Backend Services
- Authentication Service (JWT/OAuth)
- Attendance Service
- Task Management Service
- Reporting Service
- AI Service
- Notification Service

### Data Layer
- PostgreSQL (Primary DB)
- Redis (Cache)
- Object Storage (S3/MinIO)

---

## 3. Multi-Tenant Hierarchy Design

Hierarchy:
Central → Department → State → District → Organization → User

Each organization:
- Has isolated data
- Shares aggregated metrics upward
- Maintains autonomy

---

## 4. Database Design

### Core Tables
- organizations
- users
- attendance
- tasks
- task_assignments
- reports

### Data Warehouse Tables
- fact_attendance
- fact_tasks
- dim_user
- dim_organization
- dim_date
- agg_daily_attendance
- agg_monthly_kpi

### ML Tables
- ml_anomaly_detections
- ml_predictions
- ml_model_performance

---

## 5. Data Aggregation Design

### Real-Time (Hot Path)
- Event-driven architecture
- Stream processing (Kafka/Flink)
- Redis for real-time metrics

### Batch (Cold Path)
- Scheduled jobs (Airflow)
- Daily/Weekly/Monthly KPI calculations
- Model retraining pipeline

---

## 6. AI/ML Design

### Anomaly Detection
- Isolation Forest
- LSTM Autoencoder
- Outputs: anomaly score, confidence, recommendation

### Pattern Recognition
- Time Series (ARIMA/Prophet)

### Predictive Modeling
- Random Forest / XGBoost

### Clustering
- K-Means / DBSCAN

### NLP
- BERT-based classification

Human-in-the-loop validation required before enforcement actions.

---

## 7. KPI Engine Design

### Example Formulas

Attendance Rate:
(Days Present / Total Working Days) × 100

Punctuality Score:
(On-time Check-ins / Total Check-ins) × 100

Productivity Index:
(Tasks Completed / Tasks Assigned) × Weight Factor

Efficiency Score:
(Actual Hours / Estimated Hours) × Quality Factor

KPIs calculated at:
- User Level
- Team Level
- Organization Level
- State Level

---

## 8. Security Design

- Web Application Firewall
- TLS encryption
- Role-Based Access Control
- Data encryption at rest
- Audit logging
- Privacy-first architecture

---

## 9. Deployment Design

### Production Setup
- Load Balancer (Nginx/HAProxy)
- Multiple Backend Instances
- PostgreSQL Master + Replica
- Redis Primary + Replica
- S3 Storage
- Monitoring (Prometheus/Grafana)
- Logging (ELK Stack)

---

## 10. Technology Stack

Frontend:
- React.js
- Chart.js/D3.js

Backend:
- FastAPI (Python) or Node.js

Database:
- PostgreSQL

Cache:
- Redis

AI:
- Python (scikit-learn, TensorFlow)

Infrastructure:
- Docker
- Kubernetes
- AWS / Government Cloud

---

## 11. Design Principles

- Governance Observability, not surveillance
- Self-configurable (no hardcoding KPIs)
- Human-in-the-loop AI
- Vendor-neutral architecture
- Privacy-first design
- Scalable & cloud-native
