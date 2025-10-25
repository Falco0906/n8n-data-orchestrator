# 🔧 Fix: Simple Setup for n8n

## The Problem:
The imported workflow uses nodes that aren't available in your n8n version.

## The Solution:
Use the simplified workflow I just created.

## Step-by-Step Fix:

### 1. First, create PostgreSQL credentials in n8n:
1. Go to **Settings** → **Credentials** 
2. Click **"+ Add Credential"**
3. Search for **"PostgreSQL"**
4. Use these settings:
   - **Name**: `PostgreSQL Default`
   - **Host**: `postgres` (not localhost!)
   - **Database**: `n8n`
   - **User**: `n8n` 
   - **Password**: `n8n_password`
   - **Port**: `5432`
   - **SSL**: Disable

### 2. Import the simple workflow:
1. Import this file instead: `workflows/simple-collector.json`
2. The workflow will use basic n8n nodes that definitely exist

### 3. Test the simple webhook:
```bash
curl -X POST http://localhost:5678/webhook/collector \
  -H 'Content-Type: application/json' \
  -d '{
    "test": true,
    "message": "Hello from simple workflow!",
    "executionId": "test-123"
  }'
```

### 4. Check if it worked:
```bash
docker exec -it n8n-postgres psql -U n8n -d n8n -c "SELECT * FROM audit_logs ORDER BY created_at DESC LIMIT 3;"
```

## Why This Happened:
- The original workflows used advanced nodes like `writeFile`
- Your n8n version might not have all these nodes
- The simple version uses only basic, guaranteed-to-exist nodes

## What the Simple Workflow Does:
1. **Webhook** - Receives your POST request
2. **PostgreSQL** - Logs data to database  
3. **Respond** - Sends back a success message

This is perfect for testing that everything works!