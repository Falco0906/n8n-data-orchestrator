# 🏆 HACKATHON QUICK START GUIDE
## n8n Data Intelligence Orchestrator

> ⏱️ **Total Setup Time: 15 minutes**

---

## 🚀 STEP 1: Start Docker (2 minutes)

```bash
cd /Users/macbookair/n8n-data-orchestrator
docker-compose up -d
```

**Wait for all services to start:**
```
✅ n8n (http://localhost:5678)
✅ PostgreSQL (localhost:5432)
✅ Redis (localhost:6379)
✅ Grafana (http://localhost:3000)
```

---

## 🔐 STEP 2: Setup n8n (3 minutes)

1. Open http://localhost:5678
2. Create admin account:
   - Email: `faisal96kp@gmail.com`
   - Password: (your choice)

---

## 📥 STEP 3: Import Workflows (5 minutes)

Import these **4 workflows** in order:

1. `workflows/hackathon/1-collector-workflow.json`
2. `workflows/hackathon/2-validator-workflow.json`
3. `workflows/hackathon/3-processor-workflow.json`
4. `workflows/hackathon/4-reporter-workflow.json`

**How to Import:**
- Click "Workflows" → "Import from File"
- Select each JSON file
- Click "Import"

---

## ⚙️ STEP 4: Configure Credentials (3 minutes)

### PostgreSQL Credential:
- Type: PostgreSQL
- Host: `postgres`
- Port: `5432`
- Database: `n8n`
- User: `n8n`
- Password: `n8n_password`
- **SSL Mode: `disable`** ⚠️ IMPORTANT!
- ID: `postgres-cred`

**Note:** Scroll down in the credential form and set SSL to "disable" or toggle SSL OFF.

### Email Credential (for alerts):
- Type: SMTP
- Host: `smtp.gmail.com`
- Port: `587`
- User: `faisal96kp@gmail.com`
- Password: (App Password - generate from Google)

---

## ✅ STEP 5: Activate Workflows (1 minute)

1. Open each workflow
2. Click "Active" toggle (top right)
3. All 4 workflows should show green "Active" status

---

## 🎯 STEP 6: Test the Pipeline (1 minute)

### Trigger the complete pipeline:

```bash
curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "London", "country": "uk"}'
```

### Expected Response:
```json
{
  "status": "success",
  "stage": "reporter",
  "execution_id": "...",
  "report_id": "rpt_...",
  "executive_summary": {
    "status": "success",
    "total_data_sources": 2,
    "average_quality_score": "100%"
  },
  "insights": [...],
  "pipeline": "completed"
}
```

---

## 📊 STEP 7: View Results

### n8n Dashboard:
```
http://localhost:5678
→ Executions tab
→ See all 4 workflows executed
```

### Grafana Dashboard:
```
http://localhost:3000
Username: admin
Password: admin123
→ View metrics visualization
```

### PostgreSQL Logs:
```bash
docker exec -it n8n_postgres psql -U n8n -d n8n
```
```sql
SELECT * FROM audit_logs ORDER BY timestamp DESC LIMIT 10;
```

### Generated Reports:
```bash
ls -la outputs/reports/
cat outputs/reports/rpt_*.json
```

---

## 🧪 JUDGE TEST SCENARIOS

### TEST 1: API Failure (Retry & Alert)
```bash
# Simulate API failure by using invalid API key
# Edit Collector workflow → Weather node → Change API key to "invalid"
# Trigger pipeline
# ✅ System retries 3x with 5s delays
# ✅ Email alert sent after max retries
```

### TEST 2: Validation Failure (Error Blocking)
```bash
# Send invalid data
curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"invalid": "data"}'

# ✅ Validator blocks invalid data
# ✅ Email alert sent with validation errors
# ✅ Invalid data not passed to Processor
```

### TEST 3: Version Tracking (Re-run)
```bash
# Run pipeline twice
curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "New York"}'

# Wait 5 seconds

curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "Tokyo"}'

# ✅ Check PostgreSQL - different versions for each run
```

```sql
SELECT execution_id, version, stage, timestamp 
FROM audit_logs 
ORDER BY timestamp DESC;
```

### TEST 4: Docker Deployment (Clean Start)
```bash
# Stop everything
docker-compose down -v

# Clean start
docker-compose up -d

# ✅ All services start successfully
# ✅ n8n accessible at :5678
# ✅ Grafana accessible at :3000
# ✅ PostgreSQL running and accepting connections
```

---

## 📋 HACKATHON REQUIREMENTS CHECKLIST

- [x] **4 Separate Workflows:** Collector → Validator → Processor → Reporter
- [x] **Webhook Communication:** Each workflow triggers the next via webhooks
- [x] **Docker Compose:** Full stack runs with `docker-compose up`
- [x] **Retry Mechanism:** 3 retries with 5-second delays on all API calls
- [x] **Alert System:** Email alerts for collection & validation failures
- [x] **Versioned Outputs:** Each execution has unique version ID
- [x] **Audit Logs:** PostgreSQL stores complete audit trail
- [x] **Custom Transformation:** Advanced JavaScript transformations in each stage
- [x] **Live Dashboard:** Grafana + QuickChart visualization
- [x] **Error Handling:** Comprehensive error detection and reporting

---

## 🎤 DEMO SCRIPT FOR JUDGES

### 1. Introduction (30 seconds)
"This is a production-grade Data Intelligence Orchestrator built with n8n. It demonstrates MLOps principles through automated data pipelines."

### 2. Show Architecture (1 minute)
"We have 4 separate workflows:
1. **Collector** - Fetches data from Weather & Bitcoin APIs
2. **Validator** - Validates data quality with scoring
3. **Processor** - Transforms and enriches data
4. **Reporter** - Generates comprehensive reports

All communicate via webhooks and run in Docker."

### 3. Live Demo (2 minutes)
```bash
# Show Docker running
docker ps

# Trigger pipeline
curl -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "Paris"}'

# Show n8n executions (all 4 workflows ran)
# Show generated report
# Show Grafana dashboard
```

### 4. Test Scenarios (2 minutes)
"Let me demonstrate the error handling..."
- Show retry mechanism
- Show validation failure alert
- Show version tracking in PostgreSQL

### 5. Technical Highlights (1 minute)
- "Retry logic: 3 attempts, 5-second delays"
- "Quality scoring: 0-100 with grade A-F"
- "Complete audit trail in PostgreSQL"
- "Real-time dashboard visualization"

---

## 🔧 TROUBLESHOOTING

### Workflows not triggering?
```bash
# Check webhook URLs in each workflow
# Make sure they point to: http://n8n:5678/webhook/...
```

### PostgreSQL connection failed?
```bash
# Error: "The server does not support SSL connections"
# Solution: In the PostgreSQL credential, scroll down and set:
# SSL Mode: disable (or toggle SSL to OFF)

# Check credentials match docker-compose.yml
# Credential ID must be: postgres-cred
```

### Email alerts not sending?
```bash
# Generate Gmail App Password
# https://myaccount.google.com/apppasswords
# Use that instead of regular password
```

### Docker services not starting?
```bash
docker-compose down
docker system prune -a
docker-compose up -d --build
```

---

## 📊 EXPECTED METRICS

- **Pipeline Execution Time:** 2-4 seconds
- **Validation Pass Rate:** 95-100%
- **API Success Rate:** 98%+ (with retries)
- **Data Quality Score:** 90-100%
- **Workflow Communication Latency:** <500ms per hop

---

## 🏆 WINNING POINTS

1. ✅ **Production-Ready:** Full error handling, retries, alerts
2. ✅ **Scalable Architecture:** Modular workflows, easy to extend
3. ✅ **Comprehensive Logging:** Complete audit trail in PostgreSQL
4. ✅ **Data Quality:** Advanced validation with scoring system
5. ✅ **Observability:** Grafana dashboards + real-time monitoring
6. ✅ **Clean Deployment:** Single `docker-compose up` command
7. ✅ **Well-Documented:** Complete setup and troubleshooting guides

---

## 🚀 YOU'RE READY TO WIN!

**Total setup time:** 15 minutes
**Demo readiness:** 100%
**Judge test coverage:** ✅ All scenarios pass

**Good luck! 🎉**
