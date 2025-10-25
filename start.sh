#!/bin/bash

# n8n Data Orchestrator Quick Start Script
# This script initializes the environment and starts the services

set -e

echo "🚀 n8n Data Intelligence Orchestrator Setup"
echo "=============================================="

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  IMPORTANT: Please edit .env file with your secure passwords before starting!"
    echo "   Required: Update POSTGRES_PASSWORD, REDIS_PASSWORD, N8N_BASIC_AUTH_PASSWORD, GF_SECURITY_ADMIN_PASSWORD, N8N_ENCRYPTION_KEY"
    read -p "Press Enter to continue after updating .env file..."
fi

# Create necessary directories
echo "📁 Creating data directories..."
mkdir -p data/{postgres,redis,n8n,grafana}
mkdir -p logs/{n8n,grafana,nginx}
mkdir -p outputs/{collector,validator,processor,reporter}

# Set permissions
echo "🔐 Setting permissions..."
chmod 755 data logs outputs
chmod -R 777 data/postgres data/redis data/n8n data/grafana

# Start services
echo "🐳 Starting Docker services..."
docker compose up -d postgres redis

echo "⏳ Waiting for database to be ready..."
sleep 10

# Initialize Grafana database
echo "🗄️  Initializing Grafana database..."
docker compose exec postgres psql -U n8n -d n8n -c "CREATE DATABASE grafana;" 2>/dev/null || echo "Grafana database already exists"

# Start remaining services
echo "🚀 Starting n8n and Grafana..."
docker compose up -d

echo ""
echo "✅ Setup complete!"
echo ""
echo "🌐 Access URLs:"
echo "   n8n:      http://localhost:5678"
echo "   Grafana:  http://localhost:3000"
echo ""
echo "🔑 Default Credentials (update in .env):"
echo "   n8n:      admin / admin_password"
echo "   Grafana:  admin / admin_password"
echo ""
echo "📊 To view logs:"
echo "   docker compose logs -f n8n"
echo "   docker compose logs -f grafana"
echo ""
echo "🛑 To stop:"
echo "   docker compose down"
echo ""
echo "🔧 To include production features:"
echo "   docker compose --profile production up -d"
echo "   docker compose --profile logging up -d"