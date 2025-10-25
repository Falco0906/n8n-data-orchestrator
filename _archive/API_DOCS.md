# n8n Data Intelligence Orchestrator - API Documentation

## Overview

The n8n Data Intelligence Orchestrator provides a comprehensive REST API and webhook infrastructure for automated data collection, validation, processing, and reporting. This document covers all available endpoints, data schemas, and integration patterns.

## Base Configuration

- **Base URL**: `http://localhost:5678` (development) / `https://your-domain.com` (production)
- **Authentication**: Basic Auth (username: `admin`, password: `admin_password`)
- **Content-Type**: `application/json`
- **API Version**: `v1`

## Webhook Endpoints

### 1. Data Collector Webhook

**Endpoint**: `POST /webhook/data-collector`

Triggers the main data collection workflow that fetches weather and news data.

**Request Body**: 
```json
{
  "trigger_type": "manual|scheduled|api",
  "location": {
    "city": "London",
    "country": "UK",
    "lat": 51.5074,
    "lon": -0.1278
  },
  "data_sources": ["weather", "news"],
  "options": {
    "include_forecast": true,
    "news_category": "general",
    "max_news_articles": 10
  }
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Data collection initiated",
  "execution_id": "12345",
  "timestamp": "2024-01-15T10:30:00Z",
  "next_webhook": "/webhook/data-validator"
}
```

### 2. Data Validator Webhook

**Endpoint**: `POST /webhook/data-validator`

Validates incoming data against quality rules and business logic.

**Request Body**:
```json
{
  "data": {
    "weather": {
      "temperature": 25.5,
      "humidity": 60,
      "pressure": 1013.25,
      "description": "Partly cloudy"
    },
    "news": [
      {
        "title": "News Title",
        "description": "News description...",
        "url": "https://example.com/news",
        "publishedAt": "2024-01-15T10:00:00Z"
      }
    ]
  },
  "validation_rules": {
    "temperature_range": [-50, 50],
    "required_fields": ["temperature", "humidity"],
    "news_min_articles": 1
  }
}
```

**Response**:
```json
{
  "status": "success",
  "validation_result": {
    "is_valid": true,
    "quality_score": 0.95,
    "errors": [],
    "warnings": ["Minor data quality issue in news description"]
  },
  "processed_data": { /* validated and cleaned data */ },
  "next_webhook": "/webhook/data-processor"
}
```

### 3. Data Processor Webhook

**Endpoint**: `POST /webhook/data-processor`

Processes and enriches validated data with ML features and calculated fields.

**Request Body**:
```json
{
  "validated_data": { /* data from validator */ },
  "processing_options": {
    "enable_ml_features": true,
    "include_trends": true,
    "calculate_indices": true
  }
}
```

**Response**:
```json
{
  "status": "success",
  "processed_data": {
    "original_data": { /* original data */ },
    "enriched_fields": {
      "heat_index": 31.24,
      "comfort_level": "comfortable",
      "weather_trends": {
        "temperature_trend": "increasing",
        "pressure_trend": "stable"
      }
    },
    "ml_features": {
      "temperature_normalized": 0.755,
      "seasonal_adjustment": 1.2,
      "anomaly_score": 0.1
    }
  },
  "next_webhook": "/webhook/data-reporter"
}
```

### 4. Data Reporter Webhook

**Endpoint**: `POST /webhook/data-reporter`

Generates reports and sends notifications based on processed data.

**Request Body**:
```json
{
  "processed_data": { /* data from processor */ },
  "report_options": {
    "format": "html|json|csv",
    "include_charts": true,
    "send_notifications": true
  },
  "notification_settings": {
    "email": "admin@example.com",
    "slack_channel": "#data-alerts",
    "webhook_url": "https://hooks.slack.com/..."
  }
}
```

**Response**:
```json
{
  "status": "success",
  "report": {
    "report_id": "rpt_12345",
    "format": "html",
    "url": "/outputs/reports/report_12345.html",
    "generated_at": "2024-01-15T10:35:00Z"
  },
  "notifications_sent": {
    "email": true,
    "slack": true
  }
}
```

### 5. Alert Webhook

**Endpoint**: `POST /webhook/alert`

Receives monitoring alerts from Prometheus/Alertmanager.

**Request Body**:
```json
{
  "receiver": "webhook",
  "status": "firing|resolved",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "HighCPUUsage",
        "instance": "localhost:9100",
        "severity": "warning"
      },
      "annotations": {
        "summary": "High CPU usage detected",
        "description": "CPU usage is above 80%"
      },
      "startsAt": "2024-01-15T10:30:00Z"
    }
  ]
}
```

## REST API Endpoints

### Workflow Management

#### List Active Workflows
```http
GET /rest/workflows/active
Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=
```

#### Get Workflow Execution History
```http
GET /rest/executions?workflowId=123&limit=50
Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=
```

#### Trigger Workflow Manually
```http
POST /rest/workflows/123/execute
Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=
Content-Type: application/json

{
  "data": {
    "location": "London",
    "options": {"include_forecast": true}
  }
}
```

### Data Access

#### Get Latest Processed Data
```http
GET /api/v1/data/latest?limit=10&type=weather
Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=
```

#### Get Data by Date Range
```http
GET /api/v1/data/range?start=2024-01-01&end=2024-01-15&format=json
Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=
```

#### Get Data Quality Metrics
```http
GET /api/v1/metrics/quality?period=24h
Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=
```

## Data Schemas

### Weather Data Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "location": {
      "type": "object",
      "properties": {
        "city": {"type": "string"},
        "country": {"type": "string"},
        "lat": {"type": "number"},
        "lon": {"type": "number"}
      },
      "required": ["city", "lat", "lon"]
    },
    "current": {
      "type": "object",
      "properties": {
        "temperature": {"type": "number", "minimum": -50, "maximum": 50},
        "humidity": {"type": "number", "minimum": 0, "maximum": 100},
        "pressure": {"type": "number", "minimum": 900, "maximum": 1100},
        "wind_speed": {"type": "number", "minimum": 0},
        "wind_deg": {"type": "number", "minimum": 0, "maximum": 360},
        "visibility": {"type": "number", "minimum": 0},
        "uv_index": {"type": "number", "minimum": 0},
        "description": {"type": "string"},
        "icon": {"type": "string"}
      },
      "required": ["temperature", "humidity", "description"]
    },
    "forecast": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "date": {"type": "string", "format": "date"},
          "temp_min": {"type": "number"},
          "temp_max": {"type": "number"},
          "description": {"type": "string"}
        }
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "source": {"type": "string", "default": "OpenWeatherMap"},
        "collected_at": {"type": "string", "format": "date-time"},
        "api_calls_remaining": {"type": "number"}
      }
    }
  },
  "required": ["location", "current", "metadata"]
}
```

### News Data Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "articles": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "title": {"type": "string", "maxLength": 200},
          "description": {"type": "string", "maxLength": 500},
          "content": {"type": "string"},
          "url": {"type": "string", "format": "uri"},
          "urlToImage": {"type": "string", "format": "uri"},
          "publishedAt": {"type": "string", "format": "date-time"},
          "source": {
            "type": "object",
            "properties": {
              "id": {"type": "string"},
              "name": {"type": "string"}
            }
          },
          "author": {"type": "string"},
          "category": {"type": "string"},
          "language": {"type": "string", "pattern": "^[a-z]{2}$"}
        },
        "required": ["title", "url", "publishedAt"]
      }
    },
    "metadata": {
      "type": "object",
      "properties": {
        "totalResults": {"type": "number"},
        "source": {"type": "string", "default": "NewsAPI"},
        "collected_at": {"type": "string", "format": "date-time"},
        "query_parameters": {
          "type": "object",
          "properties": {
            "category": {"type": "string"},
            "country": {"type": "string"},
            "pageSize": {"type": "number"}
          }
        }
      }
    }
  },
  "required": ["articles", "metadata"]
}
```

### Processed Data Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "id": {"type": "string"},
    "timestamp": {"type": "string", "format": "date-time"},
    "data_type": {"type": "string", "enum": ["weather", "news", "combined"]},
    "raw_data": {"type": "object"},
    "validated_data": {"type": "object"},
    "enriched_data": {
      "type": "object",
      "properties": {
        "quality_score": {"type": "number", "minimum": 0, "maximum": 1},
        "completeness_score": {"type": "number", "minimum": 0, "maximum": 1},
        "ml_features": {"type": "object"},
        "calculated_fields": {"type": "object"},
        "anomaly_detection": {
          "type": "object",
          "properties": {
            "is_anomaly": {"type": "boolean"},
            "anomaly_score": {"type": "number"},
            "anomaly_type": {"type": "string"}
          }
        }
      }
    },
    "processing_metadata": {
      "type": "object",
      "properties": {
        "processing_time_ms": {"type": "number"},
        "workflow_id": {"type": "string"},
        "execution_id": {"type": "string"},
        "version": {"type": "string"}
      }
    }
  },
  "required": ["id", "timestamp", "data_type", "raw_data"]
}
```

## Error Responses

### Standard Error Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Data validation failed",
    "details": {
      "field": "temperature",
      "reason": "Value out of acceptable range",
      "received": 75,
      "expected": "between -50 and 50"
    },
    "timestamp": "2024-01-15T10:30:00Z",
    "request_id": "req_12345"
  }
}
```

### Common Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `VALIDATION_ERROR` | Data validation failed | 400 |
| `AUTHENTICATION_ERROR` | Invalid credentials | 401 |
| `RATE_LIMIT_EXCEEDED` | Too many requests | 429 |
| `EXTERNAL_API_ERROR` | External API failure | 502 |
| `PROCESSING_ERROR` | Data processing failed | 500 |
| `WORKFLOW_ERROR` | Workflow execution failed | 500 |
| `DATABASE_ERROR` | Database operation failed | 500 |

## Rate Limiting

- **API Endpoints**: 100 requests per minute per IP
- **Webhook Endpoints**: 500 requests per minute per IP
- **Authenticated Requests**: 1000 requests per minute per user

## Authentication

### Basic Authentication
```bash
curl -X POST \
  http://localhost:5678/webhook/data-collector \
  -H 'Authorization: Basic YWRtaW46YWRtaW5fcGFzc3dvcmQ=' \
  -H 'Content-Type: application/json' \
  -d '{"trigger_type": "api", "location": {"city": "London", "lat": 51.5074, "lon": -0.1278}}'
```

### API Key Authentication (Optional)
```bash
curl -X GET \
  http://localhost:5678/api/v1/data/latest \
  -H 'X-API-Key: your_api_key_here' \
  -H 'Content-Type: application/json'
```

## Integration Examples

### Python Integration

```python
import requests
import json
from base64 import b64encode

class N8nOrchestrator:
    def __init__(self, base_url, username, password):
        self.base_url = base_url
        self.auth = b64encode(f"{username}:{password}".encode()).decode()
        self.headers = {
            'Authorization': f'Basic {self.auth}',
            'Content-Type': 'application/json'
        }
    
    def trigger_data_collection(self, location, options=None):
        """Trigger data collection workflow"""
        payload = {
            'trigger_type': 'api',
            'location': location,
            'options': options or {}
        }
        
        response = requests.post(
            f"{self.base_url}/webhook/data-collector",
            headers=self.headers,
            json=payload
        )
        
        return response.json()
    
    def get_latest_data(self, data_type='weather', limit=10):
        """Get latest processed data"""
        response = requests.get(
            f"{self.base_url}/api/v1/data/latest",
            headers=self.headers,
            params={'type': data_type, 'limit': limit}
        )
        
        return response.json()

# Usage example
orchestrator = N8nOrchestrator(
    'http://localhost:5678',
    'admin',
    'admin_password'
)

# Trigger data collection
result = orchestrator.trigger_data_collection({
    'city': 'London',
    'lat': 51.5074,
    'lon': -0.1278
})

print(f"Collection triggered: {result['execution_id']}")
```

### JavaScript/Node.js Integration

```javascript
const axios = require('axios');

class N8nOrchestrator {
    constructor(baseUrl, username, password) {
        this.baseUrl = baseUrl;
        this.auth = Buffer.from(`${username}:${password}`).toString('base64');
        this.headers = {
            'Authorization': `Basic ${this.auth}`,
            'Content-Type': 'application/json'
        };
    }

    async triggerDataCollection(location, options = {}) {
        const payload = {
            trigger_type: 'api',
            location,
            options
        };

        try {
            const response = await axios.post(
                `${this.baseUrl}/webhook/data-collector`,
                payload,
                { headers: this.headers }
            );
            
            return response.data;
        } catch (error) {
            throw new Error(`API Error: ${error.response.data.error.message}`);
        }
    }

    async getDataQuality(period = '24h') {
        try {
            const response = await axios.get(
                `${this.baseUrl}/api/v1/metrics/quality`,
                {
                    headers: this.headers,
                    params: { period }
                }
            );
            
            return response.data;
        } catch (error) {
            throw new Error(`API Error: ${error.response.data.error.message}`);
        }
    }
}

// Usage example
const orchestrator = new N8nOrchestrator(
    'http://localhost:5678',
    'admin',
    'admin_password'
);

orchestrator.triggerDataCollection({
    city: 'London',
    lat: 51.5074,
    lon: -0.1278
}).then(result => {
    console.log(`Collection triggered: ${result.execution_id}`);
}).catch(error => {
    console.error('Error:', error.message);
});
```

## Monitoring and Metrics

### Health Check Endpoints

- **Overall Health**: `GET /healthz`
- **Database Health**: `GET /health/database`
- **External APIs Health**: `GET /health/external-apis`
- **Workflow Health**: `GET /health/workflows`

### Prometheus Metrics

Available at `GET /metrics`:

- `n8n_workflow_executions_total` - Total workflow executions
- `n8n_workflow_execution_duration_seconds` - Execution duration
- `n8n_api_requests_total` - Total API requests
- `n8n_external_api_calls_total` - External API calls
- `data_quality_score` - Current data quality score
- `data_processing_latency_seconds` - Data processing latency

## Troubleshooting

### Common Issues

1. **Webhook not responding**: Check if n8n workflows are active
2. **Authentication errors**: Verify credentials and encoding
3. **Rate limiting**: Implement exponential backoff
4. **Data validation failures**: Check data schema compliance
5. **External API errors**: Monitor API quotas and status

### Debug Mode

Enable debug logging by setting environment variable:
```bash
N8N_LOG_LEVEL=debug
```

### Support

- **Documentation**: [Full system documentation](./ARCHITECTURE.md)
- **Issues**: Check logs in `/logs/` directory
- **Monitoring**: Use Grafana dashboards at `http://localhost:3000`