-- n8n Data Intelligence Orchestrator Database Schema
-- PostgreSQL initialization script with tables, indexes, views, and functions

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create audit_logs table for workflow execution tracking
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    workflow_name VARCHAR(100) NOT NULL,
    execution_id VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL DEFAULT 'running',
    start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    end_time TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,
    retry_count INTEGER DEFAULT 0,
    version VARCHAR(100),
    validation_rate DECIMAL(5,2),
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create processed_data table for validated data tracking
CREATE TABLE IF NOT EXISTS processed_data (
    id SERIAL PRIMARY KEY,
    execution_id VARCHAR(255) NOT NULL,
    data_source VARCHAR(100) NOT NULL,
    validation_status VARCHAR(50) NOT NULL,
    version VARCHAR(100) NOT NULL,
    record_count INTEGER DEFAULT 0,
    validation_rate DECIMAL(5,2),
    processing_time_ms INTEGER,
    confidence_score DECIMAL(4,3),
    checksum VARCHAR(64),
    file_path TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (execution_id) REFERENCES audit_logs(execution_id) ON DELETE CASCADE
);

-- Create alerts table for monitoring and notifications
CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    alert_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    workflow_name VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    execution_id VARCHAR(255),
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by VARCHAR(100),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (execution_id) REFERENCES audit_logs(execution_id) ON DELETE SET NULL
);

-- Create data_versions table for version tracking and data integrity
CREATE TABLE IF NOT EXISTS data_versions (
    id SERIAL PRIMARY KEY,
    version VARCHAR(100) NOT NULL UNIQUE,
    checksum VARCHAR(64) NOT NULL,
    record_count INTEGER NOT NULL DEFAULT 0,
    file_path TEXT NOT NULL,
    file_size BIGINT NOT NULL DEFAULT 0,
    data_sources TEXT[] DEFAULT '{}',
    processing_duration_ms INTEGER,
    quality_score DECIMAL(4,3),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    INDEX (created_at, version)
);

-- Create workflow_metrics table for performance tracking
CREATE TABLE IF NOT EXISTS workflow_metrics (
    id SERIAL PRIMARY KEY,
    execution_id VARCHAR(255) NOT NULL,
    workflow_name VARCHAR(100) NOT NULL,
    execution_time_ms INTEGER NOT NULL,
    records_processed INTEGER DEFAULT 0,
    error_rate DECIMAL(5,2) DEFAULT 0.0,
    confidence_score DECIMAL(4,3),
    memory_usage_mb INTEGER,
    cpu_usage_percent DECIMAL(5,2),
    throughput_records_per_sec DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (execution_id) REFERENCES audit_logs(execution_id) ON DELETE CASCADE
);

-- Create indexes for optimal query performance
CREATE INDEX IF NOT EXISTS idx_audit_logs_workflow_name ON audit_logs(workflow_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_start_time ON audit_logs(start_time);
CREATE INDEX IF NOT EXISTS idx_audit_logs_version ON audit_logs(version);
CREATE INDEX IF NOT EXISTS idx_audit_logs_execution_id ON audit_logs(execution_id);

CREATE INDEX IF NOT EXISTS idx_processed_data_execution_id ON processed_data(execution_id);
CREATE INDEX IF NOT EXISTS idx_processed_data_version ON processed_data(version);
CREATE INDEX IF NOT EXISTS idx_processed_data_data_source ON processed_data(data_source);
CREATE INDEX IF NOT EXISTS idx_processed_data_created_at ON processed_data(created_at);

CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_workflow_name ON alerts(workflow_name);
CREATE INDEX IF NOT EXISTS idx_alerts_resolved ON alerts(resolved);
CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_alert_type ON alerts(alert_type);

CREATE INDEX IF NOT EXISTS idx_data_versions_version ON data_versions(version);
CREATE INDEX IF NOT EXISTS idx_data_versions_created_at ON data_versions(created_at);
CREATE INDEX IF NOT EXISTS idx_data_versions_checksum ON data_versions(checksum);

CREATE INDEX IF NOT EXISTS idx_workflow_metrics_workflow_name ON workflow_metrics(workflow_name);
CREATE INDEX IF NOT EXISTS idx_workflow_metrics_execution_id ON workflow_metrics(execution_id);
CREATE INDEX IF NOT EXISTS idx_workflow_metrics_created_at ON workflow_metrics(created_at);

-- Create dashboard_metrics view for Grafana dashboards
CREATE OR REPLACE VIEW dashboard_metrics AS
SELECT 
    al.workflow_name,
    COUNT(*) as total_executions,
    COUNT(CASE WHEN al.status = 'success' THEN 1 END) as successful_executions,
    COUNT(CASE WHEN al.status = 'failed' THEN 1 END) as failed_executions,
    ROUND(
        (COUNT(CASE WHEN al.status = 'success' THEN 1 END)::DECIMAL / 
         NULLIF(COUNT(*), 0) * 100), 2
    ) as success_rate,
    AVG(al.duration_ms) as avg_duration_ms,
    MIN(al.start_time) as first_execution,
    MAX(COALESCE(al.end_time, al.start_time)) as last_execution,
    COUNT(CASE WHEN al.start_time >= NOW() - INTERVAL '1 hour' THEN 1 END) as executions_last_hour,
    COUNT(CASE WHEN al.start_time >= NOW() - INTERVAL '24 hours' THEN 1 END) as executions_last_24h
FROM audit_logs al
WHERE al.start_time >= NOW() - INTERVAL '7 days'
GROUP BY al.workflow_name
ORDER BY al.workflow_name;

-- Create recent_alerts view for monitoring dashboard
CREATE OR REPLACE VIEW recent_alerts AS
SELECT 
    a.id,
    a.alert_type,
    a.severity,
    a.workflow_name,
    a.message,
    a.execution_id,
    a.resolved,
    a.created_at,
    a.resolved_at,
    EXTRACT(EPOCH FROM (COALESCE(a.resolved_at, NOW()) - a.created_at)) / 60 as duration_minutes,
    al.status as execution_status
FROM alerts a
LEFT JOIN audit_logs al ON a.execution_id = al.execution_id
WHERE a.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY 
    CASE a.severity 
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    a.created_at DESC;

-- Create system_health view for overall system monitoring
CREATE OR REPLACE VIEW system_health AS
SELECT 
    'overall' as component,
    COUNT(DISTINCT al.workflow_name) as active_workflows,
    COUNT(*) as total_executions_24h,
    COUNT(CASE WHEN al.status = 'success' THEN 1 END) as successful_executions_24h,
    ROUND(
        (COUNT(CASE WHEN al.status = 'success' THEN 1 END)::DECIMAL / 
         NULLIF(COUNT(*), 0) * 100), 2
    ) as success_rate_24h,
    AVG(al.duration_ms) as avg_execution_time_ms,
    COUNT(CASE WHEN a.resolved = FALSE THEN 1 END) as unresolved_alerts,
    MAX(al.start_time) as last_execution_time,
    COUNT(DISTINCT dv.version) as versions_created_24h,
    SUM(wm.records_processed) as total_records_processed_24h
FROM audit_logs al
LEFT JOIN alerts a ON a.created_at >= NOW() - INTERVAL '24 hours'
LEFT JOIN data_versions dv ON dv.created_at >= NOW() - INTERVAL '24 hours'
LEFT JOIN workflow_metrics wm ON wm.created_at >= NOW() - INTERVAL '24 hours'
WHERE al.start_time >= NOW() - INTERVAL '24 hours';

-- Function to generate unique version strings
CREATE OR REPLACE FUNCTION generate_version()
RETURNS VARCHAR(100) AS $$
BEGIN
    RETURN 'v' || TO_CHAR(NOW(), 'YYYY-MM-DD"T"HH24-MI-SS');
END;
$$ LANGUAGE plpgsql;

-- Function for data retention and cleanup
CREATE OR REPLACE FUNCTION cleanup_old_logs(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    cutoff_date TIMESTAMP WITH TIME ZONE;
BEGIN
    cutoff_date := NOW() - INTERVAL '1 day' * days_to_keep;
    
    -- Delete old workflow metrics
    DELETE FROM workflow_metrics WHERE created_at < cutoff_date;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Delete old resolved alerts
    DELETE FROM alerts 
    WHERE resolved = TRUE 
    AND resolved_at < cutoff_date - INTERVAL '7 days';
    
    -- Delete old processed data records
    DELETE FROM processed_data 
    WHERE created_at < cutoff_date
    AND execution_id NOT IN (
        SELECT execution_id FROM audit_logs 
        WHERE start_time >= cutoff_date
    );
    
    -- Delete old audit logs (keep referenced ones)
    DELETE FROM audit_logs 
    WHERE start_time < cutoff_date
    AND execution_id NOT IN (
        SELECT DISTINCT execution_id FROM alerts WHERE resolved = FALSE
    );
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get workflow statistics for a time period
CREATE OR REPLACE FUNCTION get_workflow_stats(hours_back INTEGER DEFAULT 24)
RETURNS TABLE (
    workflow_name VARCHAR(100),
    total_executions BIGINT,
    successful_executions BIGINT,
    failed_executions BIGINT,
    success_rate DECIMAL(5,2),
    avg_duration_ms DECIMAL(10,2),
    total_records_processed BIGINT,
    avg_confidence_score DECIMAL(4,3)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        al.workflow_name,
        COUNT(*) as total_executions,
        COUNT(CASE WHEN al.status = 'success' THEN 1 END) as successful_executions,
        COUNT(CASE WHEN al.status = 'failed' THEN 1 END) as failed_executions,
        ROUND(
            (COUNT(CASE WHEN al.status = 'success' THEN 1 END)::DECIMAL / 
             NULLIF(COUNT(*), 0) * 100), 2
        ) as success_rate,
        AVG(al.duration_ms) as avg_duration_ms,
        COALESCE(SUM(wm.records_processed), 0) as total_records_processed,
        AVG(wm.confidence_score) as avg_confidence_score
    FROM audit_logs al
    LEFT JOIN workflow_metrics wm ON al.execution_id = wm.execution_id
    WHERE al.start_time >= NOW() - INTERVAL '1 hour' * hours_back
    GROUP BY al.workflow_name
    ORDER BY al.workflow_name;
END;
$$ LANGUAGE plpgsql;

-- Function to resolve alerts
CREATE OR REPLACE FUNCTION resolve_alert(alert_id INTEGER, resolved_by_user VARCHAR(100) DEFAULT 'system')
RETURNS BOOLEAN AS $$
DECLARE
    alert_found BOOLEAN := FALSE;
BEGIN
    UPDATE alerts 
    SET 
        resolved = TRUE,
        resolved_at = NOW(),
        resolved_by = resolved_by_user,
        updated_at = NOW()
    WHERE id = alert_id AND resolved = FALSE;
    
    GET DIAGNOSTICS alert_found = FOUND;
    RETURN alert_found;
END;
$$ LANGUAGE plpgsql;

-- Function to automatically update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_audit_logs_updated_at 
    BEFORE UPDATE ON audit_logs 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_alerts_updated_at 
    BEFORE UPDATE ON alerts 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to calculate execution duration and update audit_logs
CREATE OR REPLACE FUNCTION finalize_execution(
    exec_id VARCHAR(255),
    exec_status VARCHAR(50),
    retry_count_val INTEGER DEFAULT 0,
    error_msg TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    start_time_val TIMESTAMP WITH TIME ZONE;
    duration_val INTEGER;
BEGIN
    -- Get start time
    SELECT start_time INTO start_time_val 
    FROM audit_logs 
    WHERE execution_id = exec_id;
    
    IF start_time_val IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Calculate duration
    duration_val := EXTRACT(EPOCH FROM (NOW() - start_time_val)) * 1000;
    
    -- Update audit log
    UPDATE audit_logs 
    SET 
        status = exec_status,
        end_time = NOW(),
        duration_ms = duration_val,
        retry_count = retry_count_val,
        error_message = error_msg,
        updated_at = NOW()
    WHERE execution_id = exec_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions to n8n user
DO $$
BEGIN
    -- Create n8n user if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'n8n') THEN
        CREATE USER n8n WITH PASSWORD 'n8n_password';
    END IF;
    
    -- Grant database privileges
    GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO n8n;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO n8n;
    
    -- Grant privileges on views
    GRANT SELECT ON dashboard_metrics TO n8n;
    GRANT SELECT ON recent_alerts TO n8n;
    GRANT SELECT ON system_health TO n8n;
    
    -- Set default privileges for future objects
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO n8n;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO n8n;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO n8n;
END $$;

-- Create Grafana database and user
CREATE DATABASE grafana;
GRANT ALL PRIVILEGES ON DATABASE grafana TO n8n;

-- Insert sample data for testing (optional)
INSERT INTO audit_logs (workflow_name, execution_id, status, version, duration_ms) VALUES
('data-collector', 'test_exec_001', 'success', 'v2025-10-25T10-00-00', 2500),
('data-validator', 'test_exec_002', 'success', 'v2025-10-25T10-01-00', 1200),
('data-processor', 'test_exec_003', 'success', 'v2025-10-25T10-02-00', 3800),
('data-reporter', 'test_exec_004', 'success', 'v2025-10-25T10-03-00', 1800);

INSERT INTO data_versions (version, checksum, record_count, file_path, file_size) VALUES
('v2025-10-25T10-02-00', 'a1b2c3d4e5f6...', 15, '/outputs/processed-v2025-10-25T10-02-00.json', 8192);

-- Create database info view for monitoring
CREATE OR REPLACE VIEW database_info AS
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
    pg_stat_get_tuples_inserted(c.oid) as inserts,
    pg_stat_get_tuples_updated(c.oid) as updates,
    pg_stat_get_tuples_deleted(c.oid) as deletes
FROM pg_tables pt
JOIN pg_class c ON c.relname = pt.tablename
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Create maintenance procedure
CREATE OR REPLACE FUNCTION daily_maintenance()
RETURNS TEXT AS $$
DECLARE
    cleanup_result INTEGER;
    vacuum_result TEXT := '';
BEGIN
    -- Run cleanup
    SELECT cleanup_old_logs(30) INTO cleanup_result;
    
    -- Update table statistics
    ANALYZE audit_logs;
    ANALYZE processed_data;
    ANALYZE alerts;
    ANALYZE data_versions;
    ANALYZE workflow_metrics;
    
    -- Return maintenance summary
    RETURN FORMAT('Daily maintenance completed. Cleaned up %s old records. Statistics updated.', cleanup_result);
END;
$$ LANGUAGE plpgsql;

-- Log schema creation
INSERT INTO audit_logs (workflow_name, execution_id, status, version) 
VALUES ('database-init', 'schema_init_' || EXTRACT(EPOCH FROM NOW()), 'success', 'v1.0.0');

COMMIT;