# 🚀 Render Deployment Guide

## Quick Deploy to Render (Free Tier)

### Prerequisites
- GitHub account with this repo pushed
- Render account (sign up at https://render.com)

### Step 1: Connect Repository
1. Go to https://render.com/dashboard
2. Click **"New +"** → **"Blueprint"**
3. Connect your GitHub account
4. Select `n8n-data-orchestrator` repository
5. Render will auto-detect `render.yaml`

### Step 2: Configure Environment Variables
Before deploying, set these in Render dashboard:

**n8n-orchestrator service:**
- `N8N_SMTP_USER` = `faisal96kp@gmail.com`
- `N8N_SMTP_PASS` = `dnoxjefkyozpoipf`
- `N8N_SMTP_SENDER` = `faisal96kp@gmail.com`

### Step 3: Deploy
1. Click **"Apply"** - Render will create all services
2. Wait 5-10 minutes for deployment
3. Services will be available at:
   - **n8n**: `https://n8n-orchestrator.onrender.com`
   - **Frontend**: `https://n8n-frontend.onrender.com`

### Step 4: Import Workflows
1. Go to your n8n URL
2. Navigate to Workflows
3. Import from `workflows/` directory

## ⚠️ Important Notes

### Free Tier Limitations
- Services **spin down after 15 min inactivity**
- First request after sleep takes 30-60 seconds
- PostgreSQL: 1GB storage limit
- Redis: 25MB limit

### Keep Services Awake (Optional)
Add to cron or use UptimeRobot:
```bash
# Ping every 10 minutes
curl https://n8n-orchestrator.onrender.com/healthz
curl https://n8n-frontend.onrender.com
```

## 🔧 Troubleshooting

### If n8n doesn't start:
```bash
# Check logs in Render dashboard
# Verify environment variables are set
```

### If frontend can't connect to n8n:
1. Update `VITE_API_URL` in frontend service
2. Make sure CORS is enabled in n8n

## 💰 Cost Breakdown (Free Tier)
- PostgreSQL: **FREE** (1GB)
- Redis: **FREE** (25MB)
- n8n Web Service: **FREE** (750 hrs/month)
- Frontend Static Site: **FREE**

**Total: $0/month** ✨

## 🎯 Production Tips
- Upgrade to paid tier ($7/month) for:
  - No sleep/downtime
  - More storage
  - Better performance
- Use environment-specific configs
- Set up monitoring

## 🔄 Local Development (Unchanged)
Your local setup remains intact:
```bash
docker-compose up -d
npm run dev
```

Everything works exactly as before!
