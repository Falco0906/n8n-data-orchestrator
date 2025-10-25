#!/bin/bash

# Email Configuration Helper Script
# This script helps you configure Gmail SMTP for n8n email alerts

echo "================================================"
echo "📧 n8n Email Alert Configuration Helper"
echo "================================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    exit 1
fi

echo "Current email configuration in .env:"
echo ""
grep "N8N_SMTP" .env
echo ""

echo "📝 To configure Gmail SMTP for email alerts:"
echo ""
echo "1️⃣  Go to Google Account Security:"
echo "    👉 https://myaccount.google.com/security"
echo ""
echo "2️⃣  Enable 2-Factor Authentication (if not enabled)"
echo ""
echo "3️⃣  Generate App Password:"
echo "    👉 https://myaccount.google.com/apppasswords"
echo "    - Select 'Mail' as the app"
echo "    - Select your device"
echo "    - Copy the 16-character password"
echo ""
echo "4️⃣  Update your .env file with the app password:"
echo ""
echo "    N8N_SMTP_PASS=xxxx-xxxx-xxxx-xxxx"
echo ""
echo "5️⃣  Restart n8n to apply changes:"
echo ""
echo "    docker-compose restart n8n"
echo ""
echo "================================================"
echo ""

read -p "Do you want to edit the .env file now? (y/n): " edit_choice

if [ "$edit_choice" = "y" ] || [ "$edit_choice" = "Y" ]; then
    echo ""
    echo "Opening .env file in default editor..."
    ${EDITOR:-nano} .env
    
    echo ""
    read -p "Restart n8n now to apply changes? (y/n): " restart_choice
    
    if [ "$restart_choice" = "y" ] || [ "$restart_choice" = "Y" ]; then
        echo ""
        echo "🔄 Restarting n8n..."
        docker-compose restart n8n
        echo ""
        echo "✅ n8n restarted! Email alerts should now be configured."
        echo ""
        echo "🧪 To test email alerts:"
        echo "   1. Trigger the pipeline with invalid data"
        echo "   2. Check the Validator workflow for validation failures"
        echo "   3. Email should be sent to your configured address"
    else
        echo ""
        echo "⚠️  Remember to restart n8n manually:"
        echo "   docker-compose restart n8n"
    fi
else
    echo ""
    echo "📝 Edit .env manually and then run:"
    echo "   docker-compose restart n8n"
fi

echo ""
echo "================================================"
echo "✅ Configuration helper completed!"
echo "================================================"
