#!/bin/bash

echo "================================================"
echo "🧪 Testing Pipeline After Production Mode Fix"
echo "================================================"
echo ""
echo "Triggering pipeline..."
echo ""

RESPONSE=$(curl -s -X POST http://localhost:5678/webhook/collect-data \
  -H "Content-Type: application/json" \
  -d '{"location": "Amsterdam", "country": "nl"}')

echo "✅ Pipeline Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

echo "⏳ Waiting 5 seconds for all workflows to complete..."
sleep 5

echo ""
echo "================================================"
echo "📊 Checking Database Logs"
echo "================================================"
echo ""

# Get the execution_id from the response
EXEC_ID=$(echo "$RESPONSE" | jq -r '.execution_id' 2>/dev/null)

if [ -n "$EXEC_ID" ] && [ "$EXEC_ID" != "null" ]; then
    echo "Looking for execution: $EXEC_ID"
    echo ""
    docker exec -it n8n-postgres psql -U n8n -d n8n -c \
      "SELECT execution_id, stage, status, source FROM audit_logs WHERE execution_id = '$EXEC_ID' ORDER BY timestamp;"
else
    echo "Showing latest logs:"
    echo ""
    docker exec -it n8n-postgres psql -U n8n -d n8n -c \
      "SELECT execution_id, stage, status FROM audit_logs ORDER BY timestamp DESC LIMIT 20;"
fi

echo ""
echo "================================================"
echo "📈 Summary by Stage"
echo "================================================"
echo ""
docker exec -it n8n-postgres psql -U n8n -d n8n -c \
  "SELECT stage, COUNT(*) as count FROM audit_logs GROUP BY stage ORDER BY stage;"

echo ""
echo "✅ Test Complete!"
echo ""
echo "Expected: You should see rows from all 4 stages:"
echo "  - collection"
echo "  - validation"
echo "  - processing"  
echo "  - reporting"
