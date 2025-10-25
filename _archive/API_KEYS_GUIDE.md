# 🔑 API Keys Setup Guide

## Required API Keys

### 1. OpenWeather API Key
- **Website**: https://openweathermap.org/api
- **Plan**: Free (1000 calls/day)
- **Steps**:
  1. Create account
  2. Go to "API Keys" section
  3. Copy the API key
  4. Use in n8n credential as "openweather-api"

### 2. NewsAPI Key
- **Website**: https://newsapi.org/register  
- **Plan**: Free (1000 requests/day)
- **Steps**:
  1. Create account
  2. Copy API key from dashboard
  3. Use in n8n credential as "newsapi-key"

## Setting Up in n8n

### For OpenWeather:
1. n8n → Settings → Credentials → + Add Credential
2. Search: "HTTP Request Auth"
3. Name: `openweather-api`
4. Auth Type: "Query Auth"
5. Key: `appid`
6. Value: `YOUR_OPENWEATHER_API_KEY`

### For NewsAPI:
1. n8n → Settings → Credentials → + Add Credential  
2. Search: "HTTP Request Auth"
3. Name: `newsapi-key`
4. Auth Type: "Header Auth"
5. Name: `X-API-Key` 
6. Value: `YOUR_NEWSAPI_KEY`

## Test API Keys

### Test OpenWeather:
```bash
curl "http://api.openweathermap.org/data/2.5/weather?q=London&appid=YOUR_API_KEY"
```

### Test NewsAPI:
```bash
curl -H "X-API-Key: YOUR_API_KEY" "https://newsapi.org/v2/top-headlines?country=us&pageSize=5"
```

Both should return JSON data if working correctly.