#!/bin/bash
# Register OxygenAgent running on host machine (outside Docker)

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Registering Remote OxygenAgent (Running on Host)          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
AGENT_NAME="oxygen_agent_remote"
AGENT_URL="http://host.docker.internal:8082"
API_KEY="sk-1234"
GATEWAY_URL="http://localhost:4000"

echo "Step 1: Check if OxygenAgent is running on host..."
echo "  URL: http://localhost:8082"

if curl -s --max-time 5 http://localhost:8082/.well-known/agent-card.json > /dev/null 2>&1; then
    echo "  ✅ Agent is running on host"
    AGENT_INFO=$(curl -s http://localhost:8082/.well-known/agent-card.json | jq '{name, url, description}')
    echo "  Agent info:"
    echo "$AGENT_INFO" | sed 's/^/    /'
else
    echo "  ❌ Agent is NOT running on localhost:8082"
    echo ""
    echo "  Start it with:"
    echo "    cd /path/to/agentic_jarvis/oxygen_agent_service"
    echo "    python agent.py"
    exit 1
fi
echo ""

echo "Step 2: Test if gateway can reach agent via Docker..."
echo "  Testing: http://host.docker.internal:8082"

if docker exec agent-gateway python -c "import urllib.request; urllib.request.urlopen('http://host.docker.internal:8082/.well-known/agent-card.json')" > /dev/null 2>&1; then
    echo "  ✅ Gateway can reach agent"
else
    echo "  ❌ Gateway cannot reach agent via host.docker.internal"
    echo ""
    echo "  This might be a Docker networking issue."
    echo "  Try using your machine's IP address instead."
    exit 1
fi
echo ""

echo "Step 3: Check if agent is already registered..."
EXISTING=$(curl -s -H "Authorization: Bearer $API_KEY" "$GATEWAY_URL/v1/agents" | jq -e ".[] | select(.agent_name == \"$AGENT_NAME\")")

if [ -n "$EXISTING" ]; then
    echo "  ⚠️  Agent '$AGENT_NAME' is already registered"
    echo ""
    read -p "  Do you want to delete and re-register? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        AGENT_ID=$(echo "$EXISTING" | jq -r '.agent_id')
        echo "  Deleting existing agent (ID: $AGENT_ID)..."
        curl -s -X DELETE -H "Authorization: Bearer $API_KEY" \
            "$GATEWAY_URL/v1/agents/$AGENT_ID" > /dev/null
        echo "  ✅ Deleted"
    else
        echo "  Skipping registration"
        exit 0
    fi
else
    echo "  ℹ️  Agent not yet registered"
fi
echo ""

echo "Step 4: Registering agent in gateway..."
RESPONSE=$(curl -s -X POST "$GATEWAY_URL/v1/agents" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"agent_name\": \"$AGENT_NAME\",
    \"agent_card_params\": {
      \"protocolVersion\": \"1.0\",
      \"name\": \"Oxygen Agent (Remote)\",
      \"description\": \"Learning platform agent running on host machine\",
      \"url\": \"$AGENT_URL\",
      \"version\": \"1.0.0\",
      \"defaultInputModes\": [\"text\"],
      \"defaultOutputModes\": [\"text\"],
      \"capabilities\": {\"streaming\": false},
      \"skills\": []
    },
    \"litellm_params\": {\"make_public\": false}
  }")

if echo "$RESPONSE" | jq -e '.agent_id' > /dev/null 2>&1; then
    echo "  ✅ Agent registered successfully!"
    AGENT_ID=$(echo "$RESPONSE" | jq -r '.agent_id')
    echo "  Agent ID: $AGENT_ID"
else
    echo "  ❌ Registration failed"
    echo "  Response:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
echo ""

echo "Step 5: Verify registration..."
REGISTERED=$(curl -s -H "Authorization: Bearer $API_KEY" "$GATEWAY_URL/v1/agents" | \
    jq -e ".[] | select(.agent_name == \"$AGENT_NAME\")")

if [ -n "$REGISTERED" ]; then
    echo "  ✅ Agent appears in registry:"
    echo "$REGISTERED" | jq '{name: .agent_name, url: .agent_card_params.url}' | sed 's/^/    /'
else
    echo "  ❌ Agent not found in registry"
    exit 1
fi
echo ""

echo "Step 6: Testing agent invocation..."
echo "  Sending test message: 'Show courses for vishal'"

TEST_RESPONSE=$(curl -s -X POST "$GATEWAY_URL/a2a/$AGENT_NAME/message/send" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test-remote",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Show courses for vishal"}],
        "messageId": "msg-remote-1"
      }
    }
  }')

if echo "$TEST_RESPONSE" | jq -e '.result.artifacts[0].parts[0].text' > /dev/null 2>&1; then
    echo "  ✅ Agent responded successfully!"
    echo ""
    echo "  Response:"
    ANSWER=$(echo "$TEST_RESPONSE" | jq -r '.result.artifacts[0].parts[0].text')
    echo "$ANSWER" | head -10 | sed 's/^/    /'

    # Show token usage
    TOKENS=$(echo "$TEST_RESPONSE" | jq '.result.metadata.adk_usage_metadata.totalTokenCount // 0')
    if [ "$TOKENS" != "0" ]; then
        echo ""
        echo "  📊 Tokens used: $TOKENS"
    fi
else
    echo "  ❌ Agent invocation failed"
    echo "  Error:"
    echo "$TEST_RESPONSE" | jq '.' | sed 's/^/    /'
    exit 1
fi
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                     ✅ SUCCESS!                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "OxygenAgent is now registered and working!"
echo ""
echo "Test it manually:"
echo "  curl -X POST http://localhost:4000/a2a/$AGENT_NAME/message/send \\"
echo "    -H \"Authorization: Bearer sk-1234\" \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    -d '{...}' | jq ."
echo ""
echo "List all agents:"
echo "  curl -s -H \"Authorization: Bearer sk-1234\" \\"
echo "    http://localhost:4000/v1/agents | jq '.[] | .agent_name'"
