#!/bin/bash

echo "================================================"
echo "🧪 Testing n8n Workflow Communication"
echo "================================================"
echo ""

echo "1️⃣  Testing Collector webhook..."
COLLECTOR_RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "TestCity", "country": "tc"}')
echo "✅ Collector Response:"
echo "$COLLECTOR_RESPONSE" | jq '.' 2>/dev/null || echo "$COLLECTOR_RESPONSE"
echo ""

sleep 2

echo "2️⃣  Testing Validator webhook..."
VALIDATOR_RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/validate-data \
  -H "Content-Type: application/json" \
  -d '{"execution_id": "test123", "version": "v1.0", "source": "weather", "collected_at": "2025-10-25T00:00:00Z", "collection_status": "success", "record_id": "test_rec_1", "raw_data": {"main": {"temp": 20}, "weather": [{"description": "clear"}]}}')
echo "✅ Validator Response:"
echo "$VALIDATOR_RESPONSE" | jq '.' 2>/dev/null || echo "$VALIDATOR_RESPONSE"
echo ""

sleep 2

echo "3️⃣  Testing Processor webhook..."
PROCESSOR_RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/process-data \
  -H "Content-Type: application/json" \
  -d '{"execution_id": "test123", "version": "v1.0", "source": "weather"}')
echo "✅ Processor Response:"
echo "$PROCESSOR_RESPONSE" | jq '.' 2>/dev/null || echo "$PROCESSOR_RESPONSE"
echo ""

sleep 2

echo "4️⃣  Testing Reporter webhook..."
REPORTER_RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/report-data \
  -H "Content-Type: application/json" \
  -d '{"execution_id": "test123", "version": "v1.0"}')
echo "✅ Reporter Response:"
echo "$REPORTER_RESPONSE" | jq '.' 2>/dev/null || echo "$REPORTER_RESPONSE"
echo ""

echo "================================================"
echo "5️⃣  Checking database logs..."
echo "================================================"
docker exec -it n8n-postgres psql -U n8n -d n8n -c \
  "SELECT execution_id, stage, status, source FROM audit_logs WHERE execution_id = 'test123' ORDER BY timestamp;"

echo ""
echo "================================================"
echo "📊 Summary of all logged stages:"
echo "================================================"
docker exec -it n8n-postgres psql -U n8n -d n8n -c \
  "SELECT stage, COUNT(*) as count FROM audit_logs GROUP BY stage ORDER BY stage;"

echo ""
echo "✅ Test complete!"
