# 🚀 Single Workflow Deployment Guide

## Prerequisites
1. **API Keys Required:**
   ```bash
   OPENWEATHER_API_KEY=your_openweather_key
   NEWS_API_KEY=your_newsapi_key
   SLACK_WEBHOOK_URL=your_slack_webhook
   ```

2. **Database Setup:**
   ```sql
   CREATE TABLE audit_logs (
     id SERIAL PRIMARY KEY,
     timestamp TIMESTAMP,
     execution_id VARCHAR(50),
     version VARCHAR(20),
     source VARCHAR(50),
     data_type VARCHAR(30),
     status VARCHAR(20),
     metrics JSONB,
     quality_score INTEGER,
     anomaly_detected BOOLEAN
   );
   ```

## 🎯 Deployment Steps

### 1. Import Workflow
```bash
# Copy the production-single-workflow.json to n8n
cp workflows/production-single-workflow.json /tmp/
```

### 2. Configure Credentials in n8n
- **PostgreSQL**: Database connection
- **Slack API**: For notifications
- **Environment Variables**: API keys

### 3. Set Environment Variables
```bash
# In n8n settings or docker-compose.yml
OPENWEATHER_API_KEY=your_actual_key
NEWS_API_KEY=your_actual_key
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
```

### 4. Test the Pipeline
```bash
# Manual trigger via webhook
curl -X POST http://localhost:5678/webhook/data-orchestrator \
  -H "Content-Type: application/json" \
  -d '{"location": "New York", "country": "us"}'
```

## 📊 Expected Output

**Console Logs:**
```
✅ Weather Data: 22°C, Clear Sky, London
✅ News Data: 5 articles fetched
✅ Crypto Data: BTC $45,230 USD
✅ Quality Score: 94%
✅ Report Generated: rpt_1729876543210
```

**Slack Notification:**
```
✅ Data Pipeline Execution Complete
Execution ID: exec_1729876543210
Status: completed_successfully
Data Sources: 3
Quality Score: 🟢 94%
✅ No anomalies detected
```

**HTML Report:** Saved to `/outputs/reports/rpt_*.html`

## 🔧 Customization Options

### Add New Data Sources
```javascript
// In "Merge & Initial Processing" node
else if (data.someNewAPI) {
  processedItem.source = 'new-api';
  processedItem.data_type = 'custom';
  // ... custom processing
}
```

### Modify Validation Rules
```javascript
// In "Advanced Data Validation" node
if (data.data_type === 'custom') {
  // Add custom validation logic
}
```

### Custom Alerts
```javascript
// In anomaly detection section
if (customCondition) {
  processedItem.anomaly_detection.is_anomaly = true;
  processedItem.anomaly_detection.anomaly_reasons.push('Custom alert');
}
```

## 🎯 Performance Expectations

- **Execution Time**: ~2-3 seconds
- **Memory Usage**: ~50MB peak
- **Success Rate**: >98% with retry mechanisms
- **API Response Times**: 
  - OpenWeather: ~250ms
  - NewsAPI: ~180ms
  - CoinDesk: ~120ms

## 📈 Monitoring

**Health Check Endpoint:**
```
GET http://localhost:5678/webhook/data-orchestrator
Response: Pipeline status, metrics, last execution
```

**PostgreSQL Monitoring:**
```sql
SELECT 
  DATE_TRUNC('hour', timestamp) as hour,
  COUNT(*) as executions,
  AVG(quality_score) as avg_quality,
  COUNT(*) FILTER (WHERE anomaly_detected = true) as anomalies
FROM audit_logs 
WHERE timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour;
```

## 🚀 Production Tips

1. **Schedule**: Run every 15 minutes for optimal balance
2. **Error Handling**: All nodes have `continueOnFail: true` for resilience  
3. **Resource Management**: Docker resource limits prevent memory issues
4. **Backup**: PostgreSQL data is automatically backed up via our scripts
5. **Scaling**: Single workflow can handle 1000+ executions/day easily

---

**🎯 This single workflow replaces all 4 separate workflows while being more performant and easier to manage!**