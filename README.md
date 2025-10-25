# n8n Data Intelligence Orchestrator

A containerized data automation system using n8n, Grafana, and supporting tools, optimized for Apple Silicon (arm64) compatibility.

## 🎯 Project Overview

This project implements a comprehensive data intelligence orchestrator with four independent processes:

1. **Collector**: Fetch data from public APIs or files
2. **Validator**: Validate and clean incoming data  
3. **Processor**: Transform or enrich data (includes custom nodes/scripts)
4. **Reporter**: Generate reports and trigger Grafana visualization updates

## 🏗️ Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Collector  │───▶│  Validator  │───▶│  Processor  │
└─────────────┘    └─────────────┘    └─────────────┘
                                             │
┌─────────────┐    ┌─────────────┐         ▼
│   Grafana   │◄───│  Reporter   │    ┌─────────────┐
└─────────────┘    └─────────────┘    │   Storage   │
                                      └─────────────┘
```

## 🚀 Quick Start

1. **Clone and setup**:
   ```bash
   cd n8n-data-orchestrator
   ./start.sh
   ```

2. **Configure environment**:
   - Edit `.env` file with secure passwords
   - Update encryption keys and credentials

3. **Start services**:
   ```bash
   docker compose up -d
   ```

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Database
POSTGRES_PASSWORD=your_secure_password
REDIS_PASSWORD=your_redis_password

# n8n Authentication  
N8N_BASIC_AUTH_PASSWORD=your_n8n_password
N8N_ENCRYPTION_KEY=your_32_char_encryption_key

# Grafana
GF_SECURITY_ADMIN_PASSWORD=your_grafana_password
```

### Service Endpoints

- **n8n Editor**: http://localhost:5678
- **Grafana Dashboard**: http://localhost:3000  
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379 (internal)

## 📁 Directory Structure

```
├── docker-compose.yml          # Main orchestration file
├── .env.example               # Environment template
├── start.sh                   # Quick start script
├── data/                      # Persistent data volumes
│   ├── postgres/             # Database data
│   ├── redis/                # Cache data  
│   ├── n8n/                  # n8n workflows & settings
│   └── grafana/              # Grafana data
├── workflows/                 # n8n workflow exports
├── custom-nodes/             # Custom n8n nodes
├── outputs/                  # Processing outputs
│   ├── collector/
│   ├── validator/
│   ├── processor/
│   └── reporter/
├── logs/                     # Centralized logging
├── grafana/                  # Grafana configuration
│   ├── provisioning/         # Datasources & dashboards
│   └── dashboards/           # Dashboard definitions
└── nginx/                    # Reverse proxy config
```

## 🔄 Workflow Communication

Workflows communicate via:

- **Webhooks**: HTTP triggers between processes
- **Database**: Shared PostgreSQL for state management
- **File System**: Shared volumes for data exchange
- **Redis**: Caching and temporary data

### Example Workflow Chain

1. **Collector** → HTTP webhook → **Validator**
2. **Validator** → Database trigger → **Processor**  
3. **Processor** → File output → **Reporter**
4. **Reporter** → Grafana API → Dashboard update

## 📊 Monitoring & Alerting

### Grafana Dashboards

- **Overview**: System health and workflow status
- **Data Pipeline**: Processing metrics and throughput
- **Error Tracking**: Failed executions and alerts

### Alert Channels

Configure in `.env`:
- **Email**: SMTP integration
- **Slack**: Webhook notifications
- **Discord**: Bot integration

## 🛠️ Development

### Custom Nodes

Place custom nodes in `./custom-nodes/`:

```javascript
// example-custom-node.js
module.exports = {
  description: {
    displayName: 'Custom Data Processor',
    name: 'customDataProcessor',
    group: ['transform'],
    // ... node definition
  },
  async execute() {
    // Custom logic here
  }
};
```

### Testing Workflows

Use the included test script:

```bash
# Test collector endpoint
curl -X POST http://localhost:5678/webhook/test-collector \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

## 🐳 Docker Profiles

### Development (default)
```bash
docker compose up -d
```

### Production
```bash
docker compose --profile production up -d
```
Includes:
- Nginx reverse proxy
- SSL termination
- Rate limiting

### Logging
```bash
docker compose --profile logging up -d  
```
Includes:
- Log rotation
- Centralized logging
- Log aggregation

## 🔒 Security Features

- **Authentication**: Basic auth for n8n, admin accounts for Grafana
- **Encryption**: Encrypted credential storage
- **Network Isolation**: Internal Docker network
- **Rate Limiting**: Nginx-based request limiting
- **Secure Headers**: XSS protection, content type validation

## 📈 Performance Optimization

- **Redis Caching**: Session and queue management
- **Connection Pooling**: PostgreSQL optimization
- **Log Rotation**: Automated cleanup
- **Health Checks**: Service monitoring
- **Queue Processing**: Background execution

## 🚨 Troubleshooting

### Common Issues

1. **Permission Errors**:
   ```bash
   sudo chown -R $USER:$USER data/
   chmod -R 755 data/
   ```

2. **Database Connection**:
   ```bash
   docker compose logs postgres
   docker compose exec postgres pg_isready
   ```

3. **Port Conflicts**:
   ```bash
   # Check what's using ports 5678, 3000
   lsof -i :5678
   lsof -i :3000
   ```

### Logs

```bash
# View all logs
docker compose logs -f

# Specific service logs  
docker compose logs -f n8n
docker compose logs -f grafana
```

## 🧪 Testing

### Health Checks

All services include health checks:
```bash
docker compose ps
```

### API Testing

Test workflow endpoints:
```bash
# Test n8n webhook
curl http://localhost:5678/webhook/health

# Test Grafana API
curl http://admin:password@localhost:3000/api/health
```

## 📝 Production Deployment

1. **Update environment variables** for production
2. **Configure SSL certificates** in `nginx/ssl/`
3. **Set up external database** (optional)
4. **Configure backup strategy** for volumes
5. **Set up monitoring alerts**

### Backup Strategy

```bash
# Backup volumes
docker run --rm -v n8n-data-orchestrator_postgres_data:/data \
  -v $(pwd)/backups:/backup alpine \
  tar czf /backup/postgres-$(date +%Y%m%d).tar.gz /data
```

## 📞 Support

For issues and contributions:
- Check logs first: `docker compose logs -f`
- Review environment configuration
- Verify network connectivity between services

## 🔄 Updates

```bash
# Update images
docker compose pull

# Restart with new images  
docker compose up -d --force-recreate
```