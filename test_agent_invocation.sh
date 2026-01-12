#!/bin/bash
# Test script for invoking A2A agents through LiteLLM Gateway

# Configuration
GATEWAY_URL="http://localhost:4000"
API_KEY="sk-1234"
AGENT_NAME="oxygen_agent"  # Change this to your agent name

echo "Testing agent invocation via OpenAI-compatible endpoint..."
echo "=================================================="
echo ""

# Test 1: Using /chat/completions endpoint (OpenAI-compatible)
echo "1. Testing /chat/completions endpoint:"
curl -X POST "${GATEWAY_URL}/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${AGENT_NAME}\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"show learning summary for vishal\"
      }
    ]
  }" | jq '.'

echo ""
echo "=================================================="
echo ""

# Test 2: Using A2A-specific endpoint
echo "2. Testing /a2a endpoint (A2A JSON-RPC 2.0):"
curl -X POST "${GATEWAY_URL}/a2a/${AGENT_NAME}/message/send" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test-request-1",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [
          {
            "kind": "text",
            "text": "show learning summary for vishal"
          }
        ],
        "messageId": "msg-1"
      }
    }
  }' | jq '.'

echo ""
echo "=================================================="
