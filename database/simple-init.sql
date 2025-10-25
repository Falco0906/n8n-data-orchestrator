-- Simple database setup for n8n Data Orchestrator
-- Simplified version without complex syntax

-- Create tables
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    execution_id VARCHAR(255) NOT NULL,
    workflow_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    processing_time INTEGER,
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    validation_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS processed_data (
    id SERIAL PRIMARY KEY,
    execution_id VARCHAR(255) NOT NULL,
    data_source VARCHAR(50) NOT NULL,
    validation_status VARCHAR(20) DEFAULT 'valid',
    record_count INTEGER DEFAULT 0,
    processing_duration INTEGER,
    data_checksum VARCHAR(255),
    enriched_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS alerts (
    id SERIAL PRIMARY KEY,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    workflow_name VARCHAR(100),
    message TEXT NOT NULL,
    execution_id VARCHAR(255),
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS data_versions (
    id SERIAL PRIMARY KEY,
    version_id VARCHAR(100) NOT NULL UNIQUE,
    execution_id VARCHAR(255) NOT NULL,
    data_size INTEGER,
    checksum VARCHAR(255),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS workflow_metrics (
    id SERIAL PRIMARY KEY,
    workflow_name VARCHAR(100) NOT NULL,
    total_executions INTEGER DEFAULT 0,
    successful_executions INTEGER DEFAULT 0,
    failed_executions INTEGER DEFAULT 0,
    avg_processing_time DECIMAL(10,2),
    last_execution TIMESTAMP,
    success_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_execution_id ON audit_logs(execution_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_workflow ON audit_logs(workflow_name);
CREATE INDEX IF NOT EXISTS idx_audit_logs_status ON audit_logs(status);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX IF NOT EXISTS idx_processed_data_execution_id ON processed_data(execution_id);
CREATE INDEX IF NOT EXISTS idx_processed_data_source ON processed_data(data_source);
CREATE INDEX IF NOT EXISTS idx_processed_data_created_at ON processed_data(created_at);

CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON alerts(created_at);

CREATE INDEX IF NOT EXISTS idx_data_versions_version_id ON data_versions(version_id);
CREATE INDEX IF NOT EXISTS idx_data_versions_execution_id ON data_versions(execution_id);

-- Insert sample workflow metrics
INSERT INTO workflow_metrics (workflow_name, total_executions, successful_executions, failed_executions, success_rate) 
VALUES 
    ('data-collector', 0, 0, 0, 0.00),
    ('data-validator', 0, 0, 0, 0.00),
    ('data-processor', 0, 0, 0, 0.00),
    ('data-reporter', 0, 0, 0, 0.00)
ON CONFLICT DO NOTHING;

-- Test data insertion
INSERT INTO audit_logs (execution_id, workflow_name, status, records_processed) 
VALUES ('test-123', 'setup', 'success', 1);

COMMIT;