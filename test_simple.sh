#!/bin/bash
# Simple test showing the flow

echo "🧪 SIMPLE TEST - Watch the flow"
echo "================================"
echo ""

echo "Step 1: Sending request to gateway..."
echo "  URL: http://localhost:4000/a2a/test_agent/message/send"
echo "  Message: 'Greet me, my name is Alex'"
echo ""

echo "Step 2: Gateway processing..."
sleep 1

RESPONSE=$(curl -s -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "simple-test",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Greet me, my name is Alex"}],
        "messageId": "msg-simple"
      }
    }
  }')

echo "Step 3: Agent received request and processed..."
echo ""

echo "Step 4: Tool called:"
TOOL_CALL=$(echo "$RESPONSE" | jq -r '.result.history[] | select(.parts[0].metadata.adk_type == "function_call") | .parts[0].data.name + "(" + (.parts[0].data.args | tostring) + ")"')
echo "  $TOOL_CALL"
echo ""

echo "Step 5: Final response:"
ANSWER=$(echo "$RESPONSE" | jq -r '.result.artifacts[0].parts[0].text')
echo "  $ANSWER"
echo ""

TOKENS=$(echo "$RESPONSE" | jq '.result.metadata.adk_usage_metadata.totalTokenCount')
echo "📊 Tokens used: $TOKENS"
echo ""
echo "✅ Test complete!"
