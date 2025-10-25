#!/bin/bash

# n8n Data Orchestrator - Backup Script
# Comprehensive backup solution for PostgreSQL, n8n workflows, and application data

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/logs/backup.log"

# Backup retention settings
BACKUP_KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}
BACKUP_KEEP_WEEKS=${BACKUP_KEEP_WEEKS:-4}
BACKUP_KEEP_MONTHS=${BACKUP_KEEP_MONTHS:-6}

# Database settings
DB_CONTAINER="n8n-postgres"
DB_NAME=${POSTGRES_DB:-n8n}
DB_USER=${POSTGRES_USER:-n8n}
DB_PASSWORD=${POSTGRES_PASSWORD:-n8n_password}

# Timestamps
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DATE_ONLY=$(date +"%Y%m%d")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Create backup directory structure
create_backup_dirs() {
    log "Creating backup directory structure"
    
    mkdir -p "$BACKUP_DIR"/{database,workflows,data,logs}
    mkdir -p "$BACKUP_DIR"/archive/{daily,weekly,monthly}
    
    # Set permissions
    chmod 750 "$BACKUP_DIR"
    
    log "Backup directories created"
}

# Backup PostgreSQL database
backup_database() {
    log "Starting database backup"
    
    local backup_file="$BACKUP_DIR/database/n8n_db_${TIMESTAMP}.sql"
    local backup_compressed="$backup_file.gz"
    
    # Check if database container is running
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        error_exit "Database container $DB_CONTAINER is not running"
    fi
    
    # Create database dump
    log "Creating database dump"
    if docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" --no-password > "$backup_file"; then
        log "Database dump created successfully"
    else
        error_exit "Failed to create database dump"
    fi
    
    # Compress the backup
    log "Compressing database backup"
    if gzip "$backup_file"; then
        log "Database backup compressed: $backup_compressed"
        echo "$backup_compressed"
    else
        error_exit "Failed to compress database backup"
    fi
}

# Backup n8n workflows and credentials
backup_workflows() {
    log "Starting workflows backup"
    
    local workflows_backup="$BACKUP_DIR/workflows/n8n_workflows_${TIMESTAMP}.tar.gz"
    
    # Backup workflows directory
    if [[ -d "$PROJECT_DIR/workflows" ]]; then
        log "Backing up workflows directory"
        if tar -czf "$workflows_backup" -C "$PROJECT_DIR" workflows/; then
            log "Workflows backup created: $workflows_backup"
        else
            error_exit "Failed to create workflows backup"
        fi
    else
        log "Workflows directory not found, skipping"
    fi
    
    # Backup n8n data directory (includes credentials)
    local n8n_data_backup="$BACKUP_DIR/data/n8n_data_${TIMESTAMP}.tar.gz"
    if [[ -d "$PROJECT_DIR/data/n8n" ]]; then
        log "Backing up n8n data directory"
        if tar -czf "$n8n_data_backup" -C "$PROJECT_DIR/data" n8n/; then
            log "n8n data backup created: $n8n_data_backup"
        else
            log "Warning: Failed to create n8n data backup"
        fi
    fi
    
    echo "$workflows_backup"
}

# Backup application data and configurations
backup_application_data() {
    log "Starting application data backup"
    
    local app_backup="$BACKUP_DIR/data/app_data_${TIMESTAMP}.tar.gz"
    local config_files=()
    
    # Collect configuration files
    [[ -f "$PROJECT_DIR/docker-compose.yml" ]] && config_files+=("docker-compose.yml")
    [[ -f "$PROJECT_DIR/.env" ]] && config_files+=(".env")
    [[ -d "$PROJECT_DIR/grafana" ]] && config_files+=("grafana/")
    [[ -d "$PROJECT_DIR/nginx" ]] && config_files+=("nginx/")
    [[ -d "$PROJECT_DIR/monitoring" ]] && config_files+=("monitoring/")
    [[ -d "$PROJECT_DIR/database" ]] && config_files+=("database/")
    [[ -d "$PROJECT_DIR/custom-nodes" ]] && config_files+=("custom-nodes/")
    
    if [[ ${#config_files[@]} -gt 0 ]]; then
        log "Backing up application configuration files"
        if tar -czf "$app_backup" -C "$PROJECT_DIR" "${config_files[@]}"; then
            log "Application data backup created: $app_backup"
        else
            error_exit "Failed to create application data backup"
        fi
    else
        log "No configuration files found to backup"
    fi
    
    echo "$app_backup"
}

# Backup logs (recent only)
backup_logs() {
    log "Starting logs backup"
    
    local logs_backup="$BACKUP_DIR/logs/logs_${TIMESTAMP}.tar.gz"
    
    if [[ -d "$PROJECT_DIR/logs" ]]; then
        # Only backup logs from the last 7 days
        log "Backing up recent logs (last 7 days)"
        if find "$PROJECT_DIR/logs" -name "*.log" -mtime -7 -print0 | tar -czf "$logs_backup" --null -T -; then
            log "Logs backup created: $logs_backup"
        else
            log "Warning: Failed to create logs backup or no recent logs found"
        fi
    else
        log "Logs directory not found, skipping"
    fi
    
    echo "$logs_backup"
}

# Create backup manifest
create_manifest() {
    local db_backup=$1
    local workflows_backup=$2
    local app_backup=$3
    local logs_backup=$4
    
    local manifest_file="$BACKUP_DIR/backup_manifest_${TIMESTAMP}.json"
    
    log "Creating backup manifest"
    
    cat > "$manifest_file" << EOF
{
  "backup_timestamp": "$TIMESTAMP",
  "backup_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "backup_version": "1.0",
  "files": {
    "database": "$(basename "$db_backup")",
    "workflows": "$(basename "$workflows_backup")",
    "application_data": "$(basename "$app_backup")",
    "logs": "$(basename "$logs_backup")"
  },
  "checksums": {
    "database": "$(sha256sum "$db_backup" | cut -d' ' -f1)",
    "workflows": "$(sha256sum "$workflows_backup" | cut -d' ' -f1)",
    "application_data": "$(sha256sum "$app_backup" | cut -d' ' -f1)",
    "logs": "$(sha256sum "$logs_backup" | cut -d' ' -f1)"
  },
  "sizes": {
    "database": $(stat -c%s "$db_backup" 2>/dev/null || stat -f%z "$db_backup"),
    "workflows": $(stat -c%s "$workflows_backup" 2>/dev/null || stat -f%z "$workflows_backup"),
    "application_data": $(stat -c%s "$app_backup" 2>/dev/null || stat -f%z "$app_backup"),
    "logs": $(stat -c%s "$logs_backup" 2>/dev/null || stat -f%z "$logs_backup")
  },
  "system_info": {
    "hostname": "$(hostname)",
    "docker_version": "$(docker --version)",
    "os": "$(uname -a)"
  }
}
EOF
    
    log "Backup manifest created: $manifest_file"
    echo "$manifest_file"
}

# Archive old backups
archive_old_backups() {
    log "Archiving old backups"
    
    local archive_daily="$BACKUP_DIR/archive/daily"
    local archive_weekly="$BACKUP_DIR/archive/weekly"
    local archive_monthly="$BACKUP_DIR/archive/monthly"
    
    # Daily archives (keep for BACKUP_KEEP_DAYS)
    if [[ $BACKUP_KEEP_DAYS -gt 0 ]]; then
        find "$BACKUP_DIR/database" -name "*.sql.gz" -mtime +$BACKUP_KEEP_DAYS -exec mv {} "$archive_daily/" \; 2>/dev/null || true
        find "$BACKUP_DIR/workflows" -name "*.tar.gz" -mtime +$BACKUP_KEEP_DAYS -exec mv {} "$archive_daily/" \; 2>/dev/null || true
        find "$BACKUP_DIR/data" -name "*.tar.gz" -mtime +$BACKUP_KEEP_DAYS -exec mv {} "$archive_daily/" \; 2>/dev/null || true
        find "$BACKUP_DIR/logs" -name "*.tar.gz" -mtime +$BACKUP_KEEP_DAYS -exec mv {} "$archive_daily/" \; 2>/dev/null || true
    fi
    
    # Weekly archives (every Sunday, keep for BACKUP_KEEP_WEEKS weeks)
    if [[ $(date +%u) -eq 7 && $BACKUP_KEEP_WEEKS -gt 0 ]]; then
        local weeks_in_days=$((BACKUP_KEEP_WEEKS * 7))
        find "$archive_daily" -name "*" -mtime +$weeks_in_days -exec mv {} "$archive_weekly/" \; 2>/dev/null || true
    fi
    
    # Monthly archives (first day of month, keep for BACKUP_KEEP_MONTHS months)
    if [[ $(date +%d) -eq 01 && $BACKUP_KEEP_MONTHS -gt 0 ]]; then
        local months_in_days=$((BACKUP_KEEP_MONTHS * 30))
        find "$archive_weekly" -name "*" -mtime +$months_in_days -exec mv {} "$archive_monthly/" \; 2>/dev/null || true
    fi
    
    # Clean up very old archives
    if [[ $BACKUP_KEEP_MONTHS -gt 0 ]]; then
        local max_age_days=$((BACKUP_KEEP_MONTHS * 30))
        find "$archive_monthly" -name "*" -mtime +$max_age_days -delete 2>/dev/null || true
    fi
    
    log "Old backups archived"
}

# Verify backup integrity
verify_backup() {
    local manifest_file=$1
    
    log "Verifying backup integrity"
    
    if [[ ! -f "$manifest_file" ]]; then
        error_exit "Manifest file not found: $manifest_file"
    fi
    
    # Check if jq is available for JSON parsing
    if ! command -v jq &> /dev/null; then
        log "Warning: jq not available, skipping checksum verification"
        return 0
    fi
    
    # Verify checksums
    local verification_failed=false
    
    while IFS= read -r line; do
        local file_type=$(echo "$line" | cut -d: -f1)
        local expected_checksum=$(echo "$line" | cut -d: -f2)
        local file_name=$(jq -r ".files.$file_type" "$manifest_file")
        local file_path=""
        
        case $file_type in
            database) file_path="$BACKUP_DIR/database/$file_name" ;;
            workflows) file_path="$BACKUP_DIR/workflows/$file_name" ;;
            application_data) file_path="$BACKUP_DIR/data/$file_name" ;;
            logs) file_path="$BACKUP_DIR/logs/$file_name" ;;
        esac
        
        if [[ -f "$file_path" ]]; then
            local actual_checksum=$(sha256sum "$file_path" | cut -d' ' -f1)
            if [[ "$actual_checksum" == "$expected_checksum" ]]; then
                log "✓ $file_type backup verified"
            else
                log "✗ $file_type backup verification failed"
                verification_failed=true
            fi
        else
            log "✗ $file_type backup file not found: $file_path"
            verification_failed=true
        fi
    done < <(jq -r '.checksums | to_entries | .[] | "\(.key):\(.value)"' "$manifest_file")
    
    if [[ "$verification_failed" == "true" ]]; then
        error_exit "Backup verification failed"
    else
        log "All backups verified successfully"
    fi
}

# Send backup notification
send_notification() {
    local status=$1
    local manifest_file=$2
    local webhook_url=${SLACK_WEBHOOK_URL:-}
    
    if [[ -n "$webhook_url" ]]; then
        local message=""
        if [[ "$status" == "success" ]]; then
            message="✅ n8n Data Orchestrator backup completed successfully at $(date)"
        else
            message="❌ n8n Data Orchestrator backup failed at $(date)"
        fi
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$webhook_url" 2>/dev/null || log "Failed to send notification"
    fi
}

# Main backup function
main() {
    local start_time=$(date +%s)
    
    echo "🗄️  n8n Data Orchestrator - Backup Script"
    echo "=========================================="
    echo "Started: $(date)"
    echo ""
    
    log "Starting backup process"
    
    # Create backup directories
    create_backup_dirs
    
    # Perform backups
    local db_backup
    local workflows_backup
    local app_backup
    local logs_backup
    local manifest_file
    
    db_backup=$(backup_database)
    workflows_backup=$(backup_workflows)
    app_backup=$(backup_application_data)
    logs_backup=$(backup_logs)
    
    # Create manifest and verify
    manifest_file=$(create_manifest "$db_backup" "$workflows_backup" "$app_backup" "$logs_backup")
    verify_backup "$manifest_file"
    
    # Archive old backups
    archive_old_backups
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "=== Backup Summary ==="
    echo "✅ Database backup: $(basename "$db_backup")"
    echo "✅ Workflows backup: $(basename "$workflows_backup")"
    echo "✅ Application data backup: $(basename "$app_backup")"
    echo "✅ Logs backup: $(basename "$logs_backup")"
    echo "✅ Manifest: $(basename "$manifest_file")"
    echo "⏱️  Duration: ${duration} seconds"
    echo "📁 Backup location: $BACKUP_DIR"
    echo ""
    
    log "Backup process completed successfully in ${duration} seconds"
    
    # Send success notification
    send_notification "success" "$manifest_file"
}

# Error handling
trap 'error_exit "Backup script interrupted"' INT TERM

# Check dependencies
for cmd in docker gzip tar sha256sum; do
    if ! command -v "$cmd" &> /dev/null; then
        error_exit "Required command not found: $cmd"
    fi
done

# Run main function
main "$@"