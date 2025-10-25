# 🏆 n8n Data Intelligence Orchestrator
## MLOps Hackathon Project

> A production-grade data pipeline system with automated collection, validation, processing, and reporting.

---

## 🎯 **Project Overview**

This project demonstrates **MLOps principles** through automated data workflows built with n8n. It features:

- **4 Separate Workflows** communicating via webhooks
- **Automated Data Collection** from Weather & Bitcoin APIs
- **Quality Validation** with scoring system
- **Data Transformation** with enrichment
- **Comprehensive Reporting** with insights
- **Full Error Handling** with retries and alerts
- **Complete Audit Trail** in PostgreSQL
- **Live Dashboard** with Grafana
- **Docker Deployment** - runs with single command

---

## 📁 **Project Structure**

```
n8n-data-orchestrator/
├── docker-compose.yml          # Complete Docker stack
├── workflows/
│   └── hackathon/
│       ├── 1-collector-workflow.json    # Data collection
│       ├── 2-validator-workflow.json    # Data validation
│       ├── 3-processor-workflow.json    # Data processing
│       └── 4-reporter-workflow.json     # Report generation
├── grafana/
│   ├── dashboards/             # Pre-built dashboards
│   └── provisioning/           # Grafana config
├── scripts/
│   ├── backup.sh              # Database backup
│   └── restore.sh             # Database restore
└── HACKATHON_QUICKSTART.md    # Complete setup guide
```

---

## ⚡ **Quick Start (15 minutes)**

### 1. Start Docker Stack
```bash
docker-compose up -d
```

### 2. Access n8n
Open http://localhost:5678 and create an admin account

### 3. Import Workflows
Import all 4 workflows from `workflows/hackathon/` directory

### 4. Configure Credentials
- **PostgreSQL:** Host: `postgres`, User: `n8n`, Pass: `n8n_password`
- **Email:** Configure Gmail SMTP for alerts

### 5. Test Pipeline
```bash
curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "London"}'
```

**📖 Full instructions in:** `HACKATHON_QUICKSTART.md`

---

## 🏗️ **Architecture**

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  Collector  │ ───> │  Validator  │ ───> │  Processor  │ ───> │  Reporter   │
│   Workflow  │      │   Workflow  │      │   Workflow  │      │   Workflow  │
└─────────────┘      └─────────────┘      └─────────────┘      └─────────────┘
      │                     │                     │                     │
      └─────────────────────┴─────────────────────┴─────────────────────┘
                                      │
                            ┌─────────┴─────────┐
                            │                   │
                      ┌─────▼─────┐      ┌─────▼─────┐
                      │ PostgreSQL │      │  Grafana  │
                      │ Audit Logs │      │ Dashboard │
                      └───────────┘      └───────────┘
```

### Workflow Communication:
1. **Collector** fetches data from APIs → sends to Validator via webhook
2. **Validator** validates quality → sends valid data to Processor
3. **Processor** transforms & enriches → sends to Reporter
4. **Reporter** generates insights & saves reports

---

## ✅ **Hackathon Requirements**

| Requirement | Status | Implementation |
|------------|--------|----------------|
| 4 Connected Workflows | ✅ | Collector → Validator → Processor → Reporter |
| Webhook Communication | ✅ | Each workflow triggers next via webhook |
| Retry Mechanism | ✅ | 3 retries with 5s delay on all API calls |
| Alert System | ✅ | Email alerts for failures |
| Versioned Outputs | ✅ | Unique version ID per execution |
| Audit Logs | ✅ | Complete trail in PostgreSQL |
| Custom Transformation | ✅ | Advanced JavaScript in each stage |
| Live Dashboard | ✅ | Grafana + QuickChart |
| Docker Deployment | ✅ | `docker-compose up` - single command |

---

## 🧪 **Judge Test Scenarios**

### TEST 1: API Failure & Retry
```bash
# Edit collector workflow → Change API key to "invalid"
# Trigger pipeline → System retries 3x → Email alert sent
```

### TEST 2: Validation Failure
```bash
curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"invalid": "data"}'
# Invalid data blocked → Email alert sent
```

### TEST 3: Version Tracking
```bash
# Run pipeline twice → Check PostgreSQL for different versions
docker exec -it n8n_postgres psql -U n8n -d n8n
SELECT execution_id, version, stage FROM audit_logs ORDER BY timestamp DESC;
```

### TEST 4: Clean Deployment
```bash
docker-compose down -v
docker-compose up -d
# All services start successfully
```

---

## 📊 **Expected Metrics**

- **Pipeline Execution:** 2-4 seconds
- **Validation Pass Rate:** 95-100%
- **API Success Rate:** 98%+ (with retries)
- **Data Quality Score:** 90-100%
- **Workflow Latency:** <500ms per hop

---

## 🎤 **Demo Script**

### 1. Show Architecture (1 min)
"We have 4 workflows that communicate via webhooks, each handling a specific stage of the data pipeline."

### 2. Live Trigger (2 min)
```bash
docker ps  # Show all services running
curl -X POST http://localhost:5678/webhook/collect-data \
  -d '{"location": "Paris"}'
```
Show n8n executions → All 4 workflows ran successfully

### 3. View Results (1 min)
- n8n: Execution history
- Grafana: Dashboard visualization
- PostgreSQL: Audit trail

### 4. Test Error Handling (1 min)
Demonstrate retry mechanism and validation alerts

---

## 🔧 **Tech Stack**

- **Workflow Engine:** n8n (v1.0+)
- **Database:** PostgreSQL 13
- **Cache:** Redis 7
- **Monitoring:** Grafana 9
- **Container:** Docker & Docker Compose
- **APIs:** OpenWeather, CoinDesk

---

## 📚 **Documentation**

- **`HACKATHON_QUICKSTART.md`** - Complete 15-minute setup guide
- **`HACKATHON_DEPLOYMENT.md`** - Detailed deployment instructions
- **`HACKATHON_SPEEDRUN.md`** - Fast-track guide

---

## 🚀 **Key Features**

### 1. Data Collection
- Multi-source API integration
- Automatic retry on failures
- Error logging and alerting
- Version tracking

### 2. Data Validation
- Quality scoring (0-100)
- Multi-level validation rules
- Invalid data blocking
- Detailed error reporting

### 3. Data Processing
- Advanced transformations
- Data enrichment with derived metrics
- Comfort index, sentiment analysis
- Performance tracking

### 4. Reporting
- Comprehensive insights
- Executive summary
- Quality metrics
- Performance analytics
- Saved JSON reports

---

## 🏆 **Winning Points**

1. ✅ **Production-Ready:** Full error handling, retries, comprehensive alerts
2. ✅ **Scalable Architecture:** Modular workflows, easy to extend with new sources
3. ✅ **Data Quality Focus:** Advanced validation with scoring and grading
4. ✅ **Complete Observability:** Audit logs, Grafana dashboards, real-time monitoring
5. ✅ **Clean Deployment:** Single command setup, well-documented
6. ✅ **MLOps Principles:** Versioning, monitoring, automation, reproducibility

---

## 🎯 **Quick Commands**

```bash
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f n8n

# Stop everything
docker-compose down

# Clean restart
docker-compose down -v && docker-compose up -d

# Backup database
./scripts/backup.sh

# Check status
docker ps
curl http://localhost:5678/webhook/collect-data -X POST -d '{"test": true}'
```

---

**🏆 Ready to win the hackathon! Good luck!** 🎉
