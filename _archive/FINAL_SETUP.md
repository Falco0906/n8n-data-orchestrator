# 🚀 FINAL SETUP GUIDE - Import & Configure n8n Workflows

## 1. Import All 4 Workflows
Import these files in order:
1. `/Users/macbookair/n8n-data-orchestrator/workflows/final/data-collector.json`
2. `/Users/macbookair/n8n-data-orchestrator/workflows/final/data-validator.json`
3. `/Users/macbookair/n8n-data-orchestrator/workflows/final/data-processor.json`
4. `/Users/macbookair/n8n-data-orchestrator/workflows/final/data-reporter.json`

## 2. Create Required Credentials

### PostgreSQL Database
- **Name**: `PostgreSQL Database`
- **Host**: `postgres`
- **Database**: `n8n`
- **User**: `n8n`
- **Password**: `n8n_password`
- **Port**: `5432`
- **SSL**: Disable

### OpenWeather API
- **Name**: `OpenWeather API`
- **Type**: HTTP Basic Auth or Generic Credential
- **API Key**: Get from https://openweathermap.org/api (free)
- **Usage**: Replace `YOUR_OPENWEATHER_API_KEY` in collector workflow

### News API
- **Name**: `News API`
- **Type**: HTTP Basic Auth or Generic Credential  
- **API Key**: Get from https://newsapi.org/register (free)
- **Usage**: Replace `YOUR_NEWS_API_KEY` in collector workflow

## 3. Get Your API Keys

### OpenWeather API (Free - 1000 calls/day)
1. Go to: https://openweathermap.org/api
2. Sign up for free account
3. Go to "API Keys" section
4. Copy your API key
5. Test: `curl "http://api.openweathermap.org/data/2.5/weather?q=London&appid=YOUR_KEY"`

### NewsAPI (Free - 1000 requests/day)
1. Go to: https://newsapi.org/register
2. Sign up for free account
3. Copy API key from dashboard
4. Test: `curl -H "X-API-Key: YOUR_KEY" "https://newsapi.org/v2/top-headlines?country=us&pageSize=5"`

## 4. Update API Keys in Workflows
After importing, edit the Data Collector workflow:
1. Click "Get Weather" node
2. Replace `{{ $credentials.openweather_api.apiKey }}` with your actual key
3. Click "Get News" node  
4. Replace `{{ $credentials.news_api.apiKey }}` with your actual key

## 5. Activate All Workflows
1. Open each workflow
2. Toggle "Inactive" → "Active" (top-right)
3. Save each workflow

## 6. Test the Complete Pipeline

### Start the pipeline:
```bash
curl -X POST http://localhost:5678/webhook/collector \
  -H "Content-Type: application/json" \
  -d '{
    "executionId": "test-pipeline-001",
    "source": "manual"
  }'
```

### Check results:
```bash
# Check audit logs
docker exec -it n8n-postgres psql -U n8n -d n8n -c "SELECT * FROM audit_logs ORDER BY start_time DESC LIMIT 5;"

# Check processed data
docker exec -it n8n-postgres psql -U n8n -d n8n -c "SELECT * FROM processed_data ORDER BY created_at DESC LIMIT 3;"

# Check data versions
docker exec -it n8n-postgres psql -U n8n -d n8n -c "SELECT * FROM data_versions ORDER BY created_at DESC LIMIT 3;"
```

## 7. What Each Workflow Does

### Data Collector (`/webhook/collector`)
- ✅ Fetches weather from OpenWeather API
- ✅ Fetches news from NewsAPI
- ✅ Logs execution to database
- ✅ Sends data to validator
- ✅ Returns collection summary

### Data Validator (`/webhook/validator`)
- ✅ Validates data structure
- ✅ Logs valid/invalid data
- ✅ Creates alerts for invalid data
- ✅ Sends valid data to processor
- ✅ Returns validation results

### Data Processor (`/webhook/processor`)
- ✅ Saves data version with checksum
- ✅ Enriches data with ML features
- ✅ Updates processed_data table
- ✅ Sends to reporter
- ✅ Returns processing results

### Data Reporter (`/webhook/reporter`)
- ✅ Logs pipeline completion
- ✅ Updates workflow metrics
- ✅ Generates final report
- ✅ Returns pipeline summary

## 8. Expected Flow
```
POST /webhook/collector → Get APIs → Log → Validate → Process → Report → Complete
```

## 9. Success Indicators
- ✅ All 4 workflows show "Active"
- ✅ Test curl returns JSON responses
- ✅ Database tables have new records
- ✅ No error messages in n8n execution logs

## 🎉 You're Done!
Complete data orchestration pipeline with real APIs, database logging, and automated processing!