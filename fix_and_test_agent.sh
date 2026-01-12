#!/bin/bash
# Script to properly test A2A agent invocation through LiteLLM Gateway

set -e

GATEWAY_URL="http://localhost:4000"
API_KEY="sk-1234"
AGENT_PORT="8082"

echo "====================================================="
echo "A2A Agent Testing Script"
echo "====================================================="
echo ""

# Step 1: Check if agent is running and accessible
echo "Step 1: Checking if agent is accessible on port ${AGENT_PORT}..."
AGENT_CARD=$(curl -s "http://localhost:${AGENT_PORT}/.well-known/agent-card.json")
AGENT_NAME=$(echo "$AGENT_CARD" | jq -r '.name')
echo "✓ Agent found: $AGENT_NAME"
echo ""

# Step 2: Update agent URL in database to use correct Docker networking
echo "Step 2: Updating agent URL in database..."
docker exec agent-gateway-postgres psql -U litellm -d litellm -c \
  "UPDATE \"LiteLLM_AgentsTable\"
   SET agent_card_params = jsonb_set(agent_card_params, '{url}', '\"http://host.docker.internal:${AGENT_PORT}\"')
   WHERE agent_name = 'oxygen_agent';" > /dev/null

echo "✓ Agent URL updated to: http://host.docker.internal:${AGENT_PORT}"
echo ""

# Step 3: Restart gateway to clear cache
echo "Step 3: Restarting gateway to clear cache..."
docker restart agent-gateway > /dev/null
echo "Waiting for gateway to be ready..."
sleep 15
echo "✓ Gateway restarted"
echo ""

# Step 4: Verify agent is registered
echo "Step 4: Verifying agent registration..."
AGENTS=$(curl -s -H "Authorization: Bearer ${API_KEY}" "${GATEWAY_URL}/v1/agents")
echo "$AGENTS" | jq -r '.[] | "  - \(.agent_name): \(.agent_card_params.name)"'
echo ""

# Step 5: Test invocation using A2A endpoint
echo "Step 5: Testing agent invocation (A2A JSON-RPC 2.0)..."
echo "Request: show learning summary for vishal"
echo ""

RESPONSE=$(curl -s -X POST "${GATEWAY_URL}/a2a/oxygen_agent/message/send" \
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
  }')

echo "Response:"
echo "$RESPONSE" | jq '.'
echo ""

# Check if response contains error
if echo "$RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
  echo "❌ Invocation failed with error"
  echo ""
  echo "Troubleshooting tips:"
  echo "1. Check if agent is running: curl http://localhost:${AGENT_PORT}/.well-known/agent-card.json"
  echo "2. Check gateway logs: docker logs agent-gateway --tail 50"
  echo "3. Verify Docker can reach host: docker exec agent-gateway curl http://host.docker.internal:${AGENT_PORT}/.well-known/agent-card.json"
  exit 1
else
  echo "✅ Agent invocation successful!"
  echo ""
  echo "The agent is working correctly through the gateway!"
fi

echo "====================================================="
