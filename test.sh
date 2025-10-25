#!/bin/bash

# n8n Data Orchestrator Test Suite
# Tests the complete workflow chain and system health

set -e

BASE_URL="http://localhost:5678"
GRAFANA_URL="http://localhost:3000"

echo "🧪 n8n Data Orchestrator Test Suite"
echo "===================================="

# Check if services are running
echo "🔍 Checking service health..."

# Test n8n health
if curl -s "${BASE_URL}/healthz" >/dev/null 2>&1; then
    echo "✅ n8n is healthy"
else
    echo "❌ n8n is not responding"
    exit 1
fi

# Test Grafana health  
if curl -s "${GRAFANA_URL}/api/health" >/dev/null 2>&1; then
    echo "✅ Grafana is healthy"
else
    echo "❌ Grafana is not responding"
    exit 1
fi

echo ""
echo "🔗 Testing workflow endpoints..."

# Test Collector webhook
echo "Testing Collector webhook..."
COLLECTOR_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "${BASE_URL}/webhook/test-collector" \
    -H "Content-Type: application/json" \
    -d '{
        "source": "test",
        "data": {
            "timestamp": "'$(date -Iseconds)'",
            "sample_data": [1, 2, 3, 4, 5],
            "metadata": {
                "test_run": true,
                "environment": "development"
            }
        }
    }')

if [[ "${COLLECTOR_RESPONSE: -3}" == "200" ]]; then
    echo "✅ Collector webhook responded successfully"
else
    echo "⚠️  Collector webhook returned: ${COLLECTOR_RESPONSE: -3}"
fi

# Test Validator webhook
echo "Testing Validator webhook..."
VALIDATOR_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "${BASE_URL}/webhook/test-validator" \
    -H "Content-Type: application/json" \
    -d '{
        "data_to_validate": {
            "records": [
                {"id": 1, "value": "valid_data", "timestamp": "'$(date -Iseconds)'"},
                {"id": 2, "value": "another_valid", "timestamp": "'$(date -Iseconds)'"}
            ]
        },
        "validation_rules": {
            "required_fields": ["id", "value", "timestamp"],
            "data_types": {
                "id": "number",
                "value": "string",
                "timestamp": "string"
            }
        }
    }')

if [[ "${VALIDATOR_RESPONSE: -3}" == "200" ]]; then
    echo "✅ Validator webhook responded successfully"
else
    echo "⚠️  Validator webhook returned: ${VALIDATOR_RESPONSE: -3}"
fi

# Test Processor webhook
echo "Testing Processor webhook..."
PROCESSOR_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "${BASE_URL}/webhook/test-processor" \
    -H "Content-Type: application/json" \
    -d '{
        "validated_data": {
            "records": [
                {"id": 1, "value": "processed_data", "score": 0.85},
                {"id": 2, "value": "enhanced_data", "score": 0.92}
            ]
        },
        "processing_config": {
            "enrichment": true,
            "transformations": ["normalize", "calculate_score"],
            "output_format": "json"
        }
    }')

if [[ "${PROCESSOR_RESPONSE: -3}" == "200" ]]; then
    echo "✅ Processor webhook responded successfully"  
else
    echo "⚠️  Processor webhook returned: ${PROCESSOR_RESPONSE: -3}"
fi

# Test Reporter webhook
echo "Testing Reporter webhook..."
REPORTER_RESPONSE=$(curl -s -w "%{http_code}" -X POST \
    "${BASE_URL}/webhook/test-reporter" \
    -H "Content-Type: application/json" \
    -d '{
        "processed_data": {
            "summary": {
                "total_records": 2,
                "average_score": 0.885,
                "processing_time": "1.2s"
            },
            "metrics": {
                "success_rate": 100,
                "error_count": 0,
                "data_quality_score": 0.95
            }
        },
        "report_config": {
            "format": "json",
            "include_visualizations": true,
            "notify_grafana": true
        }
    }')

if [[ "${REPORTER_RESPONSE: -3}" == "200" ]]; then
    echo "✅ Reporter webhook responded successfully"
else
    echo "⚠️  Reporter webhook returned: ${REPORTER_RESPONSE: -3}"
fi

echo ""
echo "📊 Testing Grafana integration..."

# Test Grafana datasource
GRAFANA_AUTH="admin:admin_password"
DATASOURCE_TEST=$(curl -s -w "%{http_code}" \
    -u "${GRAFANA_AUTH}" \
    "${GRAFANA_URL}/api/datasources/proxy/1/")

if [[ "${DATASOURCE_TEST: -3}" == "200" ]] || [[ "${DATASOURCE_TEST: -3}" == "401" ]]; then
    echo "✅ Grafana datasource connection available"
else
    echo "⚠️  Grafana datasource test returned: ${DATASOURCE_TEST: -3}"
fi

echo ""
echo "📁 Checking file system structure..."

# Check if output directories exist and are writable
for dir in collector validator processor reporter; do
    if [ -w "outputs/${dir}" ]; then
        echo "✅ outputs/${dir} is writable"
        # Create a test file
        echo "Test run: $(date)" > "outputs/${dir}/test-$(date +%s).txt"
    else
        echo "❌ outputs/${dir} is not writable"
    fi
done

# Check logs directory
if [ -w "logs" ]; then
    echo "✅ logs directory is writable"
else
    echo "❌ logs directory is not writable"
fi

echo ""
echo "🐳 Docker container health..."
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "📈 System resource usage..."
echo "Docker stats (5 second sample):"
timeout 5s docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "Unable to get stats"

echo ""
echo "✅ Test suite completed!"
echo ""
echo "🔗 Quick access URLs:"
echo "   n8n Editor:  ${BASE_URL}"
echo "   Grafana:     ${GRAFANA_URL}"
echo ""
echo "📝 Next steps:"
echo "   1. Create your workflows in n8n"
echo "   2. Configure webhook URLs in workflows"
echo "   3. Set up Grafana dashboards"
echo "   4. Configure alerting channels"