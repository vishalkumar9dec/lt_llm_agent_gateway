#!/bin/bash
# Quick Test Commands for Test Agent

echo "=========================================="
echo "Quick Test Commands for Test Agent"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check agent is running
echo -e "${BLUE}[1/5] Checking if agent is running...${NC}"
if docker ps | grep -q test-agent; then
    echo -e "${GREEN}✅ Test agent is running${NC}"
else
    echo -e "❌ Test agent is NOT running. Start it with: docker-compose up -d test-agent"
    exit 1
fi
echo ""

# Test 2: Check agent card
echo -e "${BLUE}[2/5] Checking agent card URL...${NC}"
AGENT_URL=$(curl -s http://localhost:8090/.well-known/agent-card.json | jq -r '.url')
echo "Agent advertises URL: $AGENT_URL"
if [ "$AGENT_URL" = "http://test-agent:8090" ]; then
    echo -e "${GREEN}✅ Agent card URL is correct${NC}"
else
    echo -e "${YELLOW}⚠️  Agent card URL is: $AGENT_URL (expected: http://test-agent:8090)${NC}"
fi
echo ""

# Test 3: Check if registered in gateway
echo -e "${BLUE}[3/5] Checking if agent is registered in gateway...${NC}"
if curl -s -H "Authorization: Bearer sk-1234" http://localhost:4000/v1/agents | jq -e '.[] | select(.agent_name == "test_agent")' > /dev/null; then
    echo -e "${GREEN}✅ Agent is registered in gateway${NC}"
else
    echo -e "❌ Agent is NOT registered. Register it using the commands in DOCKERIZED_AGENT_SOLUTION.md"
    exit 1
fi
echo ""

# Test 4: Simple greeting test
echo -e "${BLUE}[4/5] Testing agent invocation (greeting)...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "quick-test",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Hi! Please greet me. My name is Vishal."}],
        "messageId": "quick-msg-1"
      }
    }
  }')

if echo "$RESPONSE" | jq -e '.result.artifacts[0].parts[0].text' > /dev/null 2>&1; then
    ANSWER=$(echo "$RESPONSE" | jq -r '.result.artifacts[0].parts[0].text')
    echo -e "${GREEN}✅ Agent response:${NC}"
    echo "$ANSWER"
else
    echo -e "❌ Failed to get response. Error:"
    echo "$RESPONSE" | jq '.'
    exit 1
fi
echo ""

# Test 5: Status check test
echo -e "${BLUE}[5/5] Testing agent invocation (status check)...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "quick-test-2",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "What is your status?"}],
        "messageId": "quick-msg-2"
      }
    }
  }')

if echo "$RESPONSE" | jq -e '.result.artifacts[0].parts[0].text' > /dev/null 2>&1; then
    ANSWER=$(echo "$RESPONSE" | jq -r '.result.artifacts[0].parts[0].text')
    echo -e "${GREEN}✅ Agent response:${NC}"
    echo "$ANSWER"
else
    echo -e "❌ Failed to get response"
    exit 1
fi
echo ""

echo "=========================================="
echo -e "${GREEN}✅ All quick tests passed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  • Run interactive tests: python3 test_agent_interactive.py"
echo "  • View manual guide: cat MANUAL_TESTING_GUIDE.md"
echo "  • View agent logs: docker logs test-agent -f"
echo "  • View gateway logs: docker logs agent-gateway -f"
