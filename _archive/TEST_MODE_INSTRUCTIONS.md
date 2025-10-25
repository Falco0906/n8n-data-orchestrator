🧪 TEST MODE INSTRUCTIONS:
==========================

The webhook keeps deactivating. Let's use test mode:

1. Go to your n8n workflow
2. Click "Execute workflow" button (top right) 
3. IMMEDIATELY run this command:

curl -X POST http://localhost:5678/webhook-test/test -H "Content-Type: application/json" -d '{"test": true}'

The webhook works for ONE call after clicking Execute.

If this works, we know n8n is fine and just need to fix the activation issue.