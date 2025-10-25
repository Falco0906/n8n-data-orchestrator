#!/bin/bash

# n8n Data Orchestrator - Restore Script
# Comprehensive restore solution for PostgreSQL, n8n workflows, and application data

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/logs/restore.log"

# Database settings
DB_CONTAINER="n8n-postgres"
DB_NAME=${POSTGRES_DB:-n8n}
DB_USER=${POSTGRES_USER:-n8n}
DB_PASSWORD=${POSTGRES_PASSWORD:-n8n_password}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --timestamp TIMESTAMP    Restore from specific backup timestamp (YYYYMMDD_HHMMSS)"
    echo "  -l, --list                   List available backups"
    echo "  -m, --manifest FILE          Restore from specific manifest file"
    echo "  -d, --database-only          Restore database only"
    echo "  -w, --workflows-only         Restore workflows only"
    echo "  -a, --app-data-only          Restore application data only"
    echo "  -f, --force                  Force restore without confirmation"
    echo "  -h, --help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list                           # List available backups"
    echo "  $0 --timestamp 20240115_143000      # Restore specific backup"
    echo "  $0 --database-only --force          # Restore only database from latest backup"
    echo "  $0 --manifest backup_manifest_20240115_143000.json  # Restore from manifest"
}

# List available backups
list_backups() {
    echo ""
    echo -e "${BLUE}📋 Available Backups${NC}"
    echo "===================="
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No backup directory found."
        return 1
    fi
    
    local manifests=()
    while IFS= read -r -d '' file; do
        manifests+=("$file")
    done < <(find "$BACKUP_DIR" -name "backup_manifest_*.json" -print0 2>/dev/null | sort -z)
    
    if [[ ${#manifests[@]} -eq 0 ]]; then
        echo "No backup manifests found."
        return 1
    fi
    
    echo "Timestamp        | Date                | Database  | Workflows | App Data  | Logs"
    echo "-----------------|---------------------|-----------|-----------|-----------|----------"
    
    for manifest in "${manifests[@]}"; do
        if command -v jq &> /dev/null; then
            local timestamp=$(jq -r '.backup_timestamp' "$manifest" 2>/dev/null || echo "unknown")
            local date=$(jq -r '.backup_date' "$manifest" 2>/dev/null || echo "unknown")
            local db_size=$(jq -r '.sizes.database' "$manifest" 2>/dev/null || echo "0")
            local wf_size=$(jq -r '.sizes.workflows' "$manifest" 2>/dev/null || echo "0")
            local app_size=$(jq -r '.sizes.application_data' "$manifest" 2>/dev/null || echo "0")
            local log_size=$(jq -r '.sizes.logs' "$manifest" 2>/dev/null || echo "0")
            
            # Convert bytes to human readable
            db_size=$(numfmt --to=iec "$db_size" 2>/dev/null || echo "$db_size")
            wf_size=$(numfmt --to=iec "$wf_size" 2>/dev/null || echo "$wf_size")
            app_size=$(numfmt --to=iec "$app_size" 2>/dev/null || echo "$app_size")
            log_size=$(numfmt --to=iec "$log_size" 2>/dev/null || echo "$log_size")
            
            printf "%-16s | %-19s | %-9s | %-9s | %-9s | %-8s\n" \
                "$timestamp" "$date" "$db_size" "$wf_size" "$app_size" "$log_size"
        else
            local basename_manifest=$(basename "$manifest")
            local timestamp=${basename_manifest#backup_manifest_}
            timestamp=${timestamp%.json}
            echo "$timestamp | (jq not available for details)"
        fi
    done
    
    echo ""
    echo "Use --timestamp to restore a specific backup."
}

# Find manifest file
find_manifest() {
    local timestamp=$1
    local manifest_file="$BACKUP_DIR/backup_manifest_${timestamp}.json"
    
    if [[ -f "$manifest_file" ]]; then
        echo "$manifest_file"
    else
        error_exit "Manifest file not found: $manifest_file"
    fi
}

# Find latest manifest
find_latest_manifest() {
    local latest_manifest=$(find "$BACKUP_DIR" -name "backup_manifest_*.json" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [[ -n "$latest_manifest" ]]; then
        echo "$latest_manifest"
    else
        error_exit "No backup manifests found"
    fi
}

# Verify backup files exist
verify_backup_files() {
    local manifest_file=$1
    
    log "Verifying backup files exist"
    
    if ! command -v jq &> /dev/null; then
        log "Warning: jq not available, skipping file verification"
        return 0
    fi
    
    local missing_files=()
    
    # Check database backup
    local db_file=$(jq -r '.files.database' "$manifest_file")
    if [[ ! -f "$BACKUP_DIR/database/$db_file" ]]; then
        missing_files+=("database: $db_file")
    fi
    
    # Check workflows backup
    local wf_file=$(jq -r '.files.workflows' "$manifest_file")
    if [[ ! -f "$BACKUP_DIR/workflows/$wf_file" ]]; then
        missing_files+=("workflows: $wf_file")
    fi
    
    # Check application data backup
    local app_file=$(jq -r '.files.application_data' "$manifest_file")
    if [[ ! -f "$BACKUP_DIR/data/$app_file" ]]; then
        missing_files+=("application_data: $app_file")
    fi
    
    # Check logs backup
    local logs_file=$(jq -r '.files.logs' "$manifest_file")
    if [[ ! -f "$BACKUP_DIR/logs/$logs_file" ]]; then
        missing_files+=("logs: $logs_file")
    fi
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        echo "Missing backup files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        error_exit "Some backup files are missing"
    fi
    
    log "All backup files verified"
}

# Stop services
stop_services() {
    log "Stopping n8n services"
    echo "Stopping services..."
    
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" stop n8n grafana 2>/dev/null || true
    
    # Wait for services to stop
    sleep 5
}

# Start services
start_services() {
    log "Starting n8n services"
    echo "Starting services..."
    
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" start postgres redis
    sleep 10
    
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" start n8n grafana
    sleep 5
}

# Restore database
restore_database() {
    local manifest_file=$1
    local force_restore=${2:-false}
    
    if [[ "$RESTORE_DATABASE_ONLY" == "false" && "$RESTORE_ALL" == "false" ]]; then
        return 0
    fi
    
    log "Starting database restore"
    echo "Restoring database..."
    
    if ! command -v jq &> /dev/null; then
        error_exit "jq is required for database restore"
    fi
    
    local db_file=$(jq -r '.files.database' "$manifest_file")
    local db_backup_path="$BACKUP_DIR/database/$db_file"
    
    if [[ ! -f "$db_backup_path" ]]; then
        error_exit "Database backup file not found: $db_backup_path"
    fi
    
    # Check if database container is running
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log "Starting database container"
        docker-compose -f "$PROJECT_DIR/docker-compose.yml" start postgres
        sleep 10
    fi
    
    # Create a backup of current database before restore
    if [[ "$force_restore" == "false" ]]; then
        log "Creating backup of current database before restore"
        local pre_restore_backup="$BACKUP_DIR/database/pre_restore_$(date +%Y%m%d_%H%M%S).sql"
        docker exec "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" --no-password > "$pre_restore_backup" || log "Warning: Could not backup current database"
    fi
    
    # Drop and recreate database
    log "Dropping and recreating database"
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\";" || error_exit "Failed to drop database"
    docker exec "$DB_CONTAINER" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\";" || error_exit "Failed to create database"
    
    # Restore database
    log "Restoring database from backup"
    if [[ "$db_file" == *.gz ]]; then
        if gunzip -c "$db_backup_path" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" --no-password; then
            log "Database restored successfully"
        else
            error_exit "Failed to restore database"
        fi
    else
        if docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" --no-password < "$db_backup_path"; then
            log "Database restored successfully"
        else
            error_exit "Failed to restore database"
        fi
    fi
}

# Restore workflows
restore_workflows() {
    local manifest_file=$1
    
    if [[ "$RESTORE_WORKFLOWS_ONLY" == "false" && "$RESTORE_ALL" == "false" ]]; then
        return 0
    fi
    
    log "Starting workflows restore"
    echo "Restoring workflows..."
    
    if ! command -v jq &> /dev/null; then
        error_exit "jq is required for workflows restore"
    fi
    
    local wf_file=$(jq -r '.files.workflows' "$manifest_file")
    local wf_backup_path="$BACKUP_DIR/workflows/$wf_file"
    
    if [[ ! -f "$wf_backup_path" ]]; then
        error_exit "Workflows backup file not found: $wf_backup_path"
    fi
    
    # Backup current workflows
    if [[ -d "$PROJECT_DIR/workflows" ]]; then
        log "Backing up current workflows"
        local current_wf_backup="$PROJECT_DIR/workflows_backup_$(date +%Y%m%d_%H%M%S)"
        cp -r "$PROJECT_DIR/workflows" "$current_wf_backup" || log "Warning: Could not backup current workflows"
    fi
    
    # Extract workflows
    log "Extracting workflows from backup"
    if tar -xzf "$wf_backup_path" -C "$PROJECT_DIR"; then
        log "Workflows restored successfully"
    else
        error_exit "Failed to restore workflows"
    fi
}

# Restore application data
restore_app_data() {
    local manifest_file=$1
    
    if [[ "$RESTORE_APP_DATA_ONLY" == "false" && "$RESTORE_ALL" == "false" ]]; then
        return 0
    fi
    
    log "Starting application data restore"
    echo "Restoring application data..."
    
    if ! command -v jq &> /dev/null; then
        error_exit "jq is required for application data restore"
    fi
    
    local app_file=$(jq -r '.files.application_data' "$manifest_file")
    local app_backup_path="$BACKUP_DIR/data/$app_file"
    
    if [[ ! -f "$app_backup_path" ]]; then
        error_exit "Application data backup file not found: $app_backup_path"
    fi
    
    # Extract application data
    log "Extracting application data from backup"
    if tar -xzf "$app_backup_path" -C "$PROJECT_DIR"; then
        log "Application data restored successfully"
    else
        error_exit "Failed to restore application data"
    fi
}

# Confirm restore operation
confirm_restore() {
    local manifest_file=$1
    local force_restore=$2
    
    if [[ "$force_restore" == "true" ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will overwrite current data!${NC}"
    echo ""
    
    if command -v jq &> /dev/null; then
        echo "Restore Details:"
        echo "  Backup Date: $(jq -r '.backup_date' "$manifest_file")"
        echo "  Backup Timestamp: $(jq -r '.backup_timestamp' "$manifest_file")"
    fi
    
    echo ""
    echo "What will be restored:"
    [[ "$RESTORE_ALL" == "true" || "$RESTORE_DATABASE_ONLY" == "true" ]] && echo "  ✓ PostgreSQL Database"
    [[ "$RESTORE_ALL" == "true" || "$RESTORE_WORKFLOWS_ONLY" == "true" ]] && echo "  ✓ n8n Workflows"
    [[ "$RESTORE_ALL" == "true" || "$RESTORE_APP_DATA_ONLY" == "true" ]] && echo "  ✓ Application Data"
    
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Restore cancelled."
        exit 0
    fi
}

# Main restore function
main() {
    local start_time=$(date +%s)
    
    echo "🔄 n8n Data Orchestrator - Restore Script"
    echo "=========================================="
    echo "Started: $(date)"
    echo ""
    
    log "Starting restore process"
    
    # Find manifest file
    local manifest_file=""
    if [[ -n "$SPECIFIC_MANIFEST" ]]; then
        if [[ -f "$SPECIFIC_MANIFEST" ]]; then
            manifest_file="$SPECIFIC_MANIFEST"
        else
            error_exit "Manifest file not found: $SPECIFIC_MANIFEST"
        fi
    elif [[ -n "$BACKUP_TIMESTAMP" ]]; then
        manifest_file=$(find_manifest "$BACKUP_TIMESTAMP")
    else
        manifest_file=$(find_latest_manifest)
        log "Using latest backup: $(basename "$manifest_file")"
    fi
    
    echo "Using manifest: $(basename "$manifest_file")"
    
    # Verify backup files
    verify_backup_files "$manifest_file"
    
    # Confirm restore
    confirm_restore "$manifest_file" "$FORCE_RESTORE"
    
    # Stop services
    stop_services
    
    # Perform restore operations
    restore_database "$manifest_file" "$FORCE_RESTORE"
    restore_workflows "$manifest_file"
    restore_app_data "$manifest_file"
    
    # Start services
    start_services
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "=== Restore Summary ==="
    echo "✅ Restore completed successfully"
    echo "⏱️  Duration: ${duration} seconds"
    echo "📁 Restored from: $(basename "$manifest_file")"
    echo ""
    echo "Services should be starting up..."
    echo "n8n will be available at: http://localhost:5678"
    echo "Grafana will be available at: http://localhost:3000"
    echo ""
    
    log "Restore process completed successfully in ${duration} seconds"
}

# Parse command line arguments
BACKUP_TIMESTAMP=""
SPECIFIC_MANIFEST=""
RESTORE_ALL="true"
RESTORE_DATABASE_ONLY="false"
RESTORE_WORKFLOWS_ONLY="false"
RESTORE_APP_DATA_ONLY="false"
FORCE_RESTORE="false"
LIST_BACKUPS="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--timestamp)
            BACKUP_TIMESTAMP="$2"
            shift 2
            ;;
        -m|--manifest)
            SPECIFIC_MANIFEST="$2"
            shift 2
            ;;
        -d|--database-only)
            RESTORE_ALL="false"
            RESTORE_DATABASE_ONLY="true"
            shift
            ;;
        -w|--workflows-only)
            RESTORE_ALL="false"
            RESTORE_WORKFLOWS_ONLY="true"
            shift
            ;;
        -a|--app-data-only)
            RESTORE_ALL="false"
            RESTORE_APP_DATA_ONLY="true"
            shift
            ;;
        -f|--force)
            FORCE_RESTORE="true"
            shift
            ;;
        -l|--list)
            LIST_BACKUPS="true"
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if we should list backups
if [[ "$LIST_BACKUPS" == "true" ]]; then
    list_backups
    exit 0
fi

# Check dependencies
for cmd in docker tar; do
    if ! command -v "$cmd" &> /dev/null; then
        error_exit "Required command not found: $cmd"
    fi
done

# Error handling
trap 'error_exit "Restore script interrupted"' INT TERM

# Run main function
main "$@"