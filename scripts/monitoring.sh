#!/bin/bash

# n8n Data Orchestrator - System Monitoring Script
# This script provides comprehensive health checks and monitoring for all services

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$PROJECT_DIR/logs/monitoring.log"
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Health check functions
check_service_health() {
    local service_name=$1
    local health_url=$2
    local expected_code=${3:-200}
    
    if curl -s -o /dev/null -w "%{http_code}" "$health_url" | grep -q "$expected_code"; then
        echo -e "${GREEN}✓${NC} $service_name is healthy"
        return 0
    else
        echo -e "${RED}✗${NC} $service_name is unhealthy"
        return 1
    fi
}

check_container_status() {
    local container_name=$1
    
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
        if [[ "$status" == "healthy" || "$status" == "no-health-check" ]]; then
            echo -e "${GREEN}✓${NC} Container $container_name is running"
            return 0
        else
            echo -e "${RED}✗${NC} Container $container_name is unhealthy (status: $status)"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} Container $container_name is not running"
        return 1
    fi
}

check_system_resources() {
    echo "=== System Resource Check ==="
    
    # CPU Usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    if (( $(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc -l) )); then
        echo -e "${RED}⚠${NC}  High CPU usage: ${cpu_usage}%"
    else
        echo -e "${GREEN}✓${NC} CPU usage: ${cpu_usage}%"
    fi
    
    # Memory Usage
    local memory_info=$(free | grep '^Mem:')
    local total_mem=$(echo $memory_info | awk '{print $2}')
    local used_mem=$(echo $memory_info | awk '{print $3}')
    local memory_percent=$(echo "scale=1; $used_mem * 100 / $total_mem" | bc)
    
    if (( $(echo "$memory_percent > $ALERT_THRESHOLD_MEMORY" | bc -l) )); then
        echo -e "${RED}⚠${NC}  High memory usage: ${memory_percent}%"
    else
        echo -e "${GREEN}✓${NC} Memory usage: ${memory_percent}%"
    fi
    
    # Disk Usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt $ALERT_THRESHOLD_DISK ]]; then
        echo -e "${RED}⚠${NC}  High disk usage: ${disk_usage}%"
    else
        echo -e "${GREEN}✓${NC} Disk usage: ${disk_usage}%"
    fi
    
    echo ""
}

check_docker_services() {
    echo "=== Docker Services Check ==="
    
    local services=("n8n-postgres" "n8n-redis" "n8n-orchestrator" "n8n-grafana")
    local all_healthy=true
    
    for service in "${services[@]}"; do
        if ! check_container_status "$service"; then
            all_healthy=false
        fi
    done
    
    echo ""
    return $([[ "$all_healthy" == "true" ]] && echo 0 || echo 1)
}

check_application_health() {
    echo "=== Application Health Check ==="
    
    local all_healthy=true
    
    # n8n health check
    if ! check_service_health "n8n" "http://localhost:5678/healthz"; then
        all_healthy=false
    fi
    
    # Grafana health check
    if ! check_service_health "Grafana" "http://localhost:3000/api/health"; then
        all_healthy=false
    fi
    
    # Database connectivity
    if docker exec n8n-postgres pg_isready -U n8n >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} PostgreSQL is accepting connections"
    else
        echo -e "${RED}✗${NC} PostgreSQL is not accepting connections"
        all_healthy=false
    fi
    
    # Redis connectivity
    if docker exec n8n-redis redis-cli ping | grep -q "PONG"; then
        echo -e "${GREEN}✓${NC} Redis is responding to ping"
    else
        echo -e "${RED}✗${NC} Redis is not responding"
        all_healthy=false
    fi
    
    echo ""
    return $([[ "$all_healthy" == "true" ]] && echo 0 || echo 1)
}

check_data_pipeline() {
    echo "=== Data Pipeline Check ==="
    
    # Check if workflows are active
    local active_workflows=$(docker exec n8n-orchestrator wget -qO- "http://localhost:5678/rest/workflows" \
        --header="Authorization: Basic $(echo -n 'admin:admin_password' | base64)" 2>/dev/null | \
        jq '[.data[] | select(.active == true)] | length' 2>/dev/null || echo "0")
    
    if [[ "$active_workflows" -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} $active_workflows workflows are active"
    else
        echo -e "${YELLOW}⚠${NC}  No active workflows found"
    fi
    
    # Check recent executions
    local recent_executions=$(docker exec n8n-postgres psql -U n8n -d n8n -t -c \
        "SELECT COUNT(*) FROM execution_entity WHERE finished_at > NOW() - INTERVAL '1 hour';" 2>/dev/null | tr -d ' ' || echo "0")
    
    if [[ "$recent_executions" -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} $recent_executions workflow executions in the last hour"
    else
        echo -e "${YELLOW}⚠${NC}  No workflow executions in the last hour"
    fi
    
    echo ""
}

check_log_files() {
    echo "=== Log Files Check ==="
    
    local log_dir="$PROJECT_DIR/logs"
    local large_logs=()
    
    if [[ -d "$log_dir" ]]; then
        while IFS= read -r -d '' file; do
            local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
            if [[ $size -gt 104857600 ]]; then # 100MB
                large_logs+=("$(basename "$file"): $(numfmt --to=iec "$size")")
            fi
        done < <(find "$log_dir" -name "*.log" -print0)
        
        if [[ ${#large_logs[@]} -gt 0 ]]; then
            echo -e "${YELLOW}⚠${NC}  Large log files detected:"
            for log in "${large_logs[@]}"; do
                echo "    $log"
            done
        else
            echo -e "${GREEN}✓${NC} Log file sizes are normal"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Log directory not found"
    fi
    
    echo ""
}

check_backup_status() {
    echo "=== Backup Status Check ==="
    
    local backup_dir="$PROJECT_DIR/backups"
    if [[ -d "$backup_dir" ]]; then
        local latest_backup=$(find "$backup_dir" -name "*.sql" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        
        if [[ -n "$latest_backup" ]]; then
            local backup_age=$(( $(date +%s) - $(stat -c %Y "$latest_backup" 2>/dev/null || stat -f %m "$latest_backup" 2>/dev/null) ))
            local backup_hours=$(( backup_age / 3600 ))
            
            if [[ $backup_hours -lt 24 ]]; then
                echo -e "${GREEN}✓${NC} Latest backup is $backup_hours hours old"
            else
                echo -e "${YELLOW}⚠${NC}  Latest backup is $backup_hours hours old (consider running backup)"
            fi
        else
            echo -e "${YELLOW}⚠${NC}  No backups found"
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Backup directory not found"
    fi
    
    echo ""
}

generate_summary_report() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=== Monitoring Summary ==="
    echo "Monitoring completed in ${duration} seconds"
    echo "Report generated: $(date)"
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Generate metrics for Prometheus (if enabled)
    local metrics_file="$PROJECT_DIR/logs/monitoring_metrics.prom"
    cat > "$metrics_file" << EOF
# HELP monitoring_check_duration_seconds Duration of monitoring checks
# TYPE monitoring_check_duration_seconds gauge
monitoring_check_duration_seconds $duration

# HELP monitoring_last_run_timestamp Last time monitoring script ran
# TYPE monitoring_last_run_timestamp gauge
monitoring_last_run_timestamp $end_time

# HELP system_cpu_usage_percent Current CPU usage percentage
# TYPE system_cpu_usage_percent gauge
system_cpu_usage_percent $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')

# HELP system_memory_usage_percent Current memory usage percentage
# TYPE system_memory_usage_percent gauge
system_memory_usage_percent $(free | awk '/^Mem:/ {printf "%.1f", $3*100/$2}')

# HELP system_disk_usage_percent Current disk usage percentage
# TYPE system_disk_usage_percent gauge
system_disk_usage_percent $(df / | tail -1 | awk '{print $5}' | sed 's/%//')
EOF
}

# Main monitoring function
main() {
    local start_time=$(date +%s)
    
    echo "🔍 n8n Data Orchestrator - System Monitoring"
    echo "=============================================="
    echo "Started: $(date)"
    echo ""
    
    log "Starting monitoring check"
    
    # Perform all checks
    check_system_resources
    check_docker_services
    check_application_health
    check_data_pipeline
    check_log_files
    check_backup_status
    
    generate_summary_report $start_time
    
    log "Monitoring check completed"
}

# Run monitoring with optional continuous mode
if [[ "${1:-}" == "--continuous" ]]; then
    echo "Running in continuous mode (every 60 seconds)..."
    while true; do
        main
        echo "Waiting 60 seconds for next check..."
        sleep 60
        clear
    done
else
    main
fi