# Manual Testing Guide for Test Agent

This guide walks you through testing the test agent manually to understand how the A2A protocol and LiteLLM gateway work.

---

## Architecture Overview

```
Your Machine
    │
    ├─> Test Script (curl/Python)
    │       │
    │       └─> LiteLLM Gateway (port 4000)
    │               │
    │               └─> Test Agent (port 8090)
    │                       │
    │                       └─> Gemini Model + Tools
```

**Flow:**
1. You send a request to LiteLLM Gateway
2. Gateway routes to the appropriate agent (test_agent)
3. Agent processes the request using its LLM and tools
4. Response flows back through gateway to you

---

## Level 1: Test Agent Directly (Bypass Gateway)

### Check if Agent is Running

```bash
# Check if container is running
docker ps | grep test-agent

# Check agent logs
docker logs test-agent --tail 20
```

### View Agent Card

The agent card describes the agent's capabilities:

```bash
curl http://localhost:8090/.well-known/agent-card.json | jq '.'
```

**What you should see:**
- `name`: "TestAgent"
- `url`: "http://test-agent:8090" ← This is the fix we implemented!
- `skills`: List of available tools (greet_user, get_status)

### Test Direct A2A Invocation

Test the agent directly (without gateway):

```bash
curl -X POST http://localhost:8090/a2a/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "direct-test-1",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "What is your status?"}],
        "messageId": "msg-direct-1"
      }
    }
  }' | jq '.result.artifacts[0].parts[0].text'
```

**Expected:** The agent should call `get_status()` tool and return status information.

---

## Level 2: Test Through LiteLLM Gateway

### Check Agent is Registered

```bash
# List all agents
curl -s -H "Authorization: Bearer sk-1234" \
  http://localhost:4000/v1/agents | jq '.[] | {name: .agent_name, url: .agent_card_params.url}'
```

**Expected:** You should see `test_agent` with URL `http://test-agent:8090`

### Simple Test: Greet User

Create a test file:

```bash
cat > /tmp/test_greet.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-greet",
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "Hi! Please greet me. My name is Vishal."}],
      "messageId": "msg-greet-1"
    }
  }
}
EOF
```

Invoke through gateway:

```bash
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_greet.json | jq '.'
```

**What happens:**
1. Gateway receives your request
2. Gateway looks up `test_agent` in its registry
3. Gateway forwards to `http://test-agent:8090` (Docker network)
4. Test agent's LLM analyzes the request
5. Agent calls `greet_user("Vishal")` tool
6. Tool returns: "Hello Vishal! I'm the Test Agent, nice to meet you!"
7. Response flows back through gateway

**Look for in response:**
- `result.artifacts[0].parts[0].text` - The final answer
- `result.history` - Full conversation including tool calls

### Test: Get Status

```bash
cat > /tmp/test_status.json << 'EOF'
{
  "jsonrpc": "2.0",
  "id": "test-status",
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "What is your operational status?"}],
      "messageId": "msg-status-1"
    }
  }
}
EOF

curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_status.json | jq '.result.artifacts[0].parts[0].text'
```

**What happens:**
- Agent recognizes you're asking about status
- Agent calls `get_status()` tool
- Tool returns: `{"status": "healthy", "agent": "TestAgent", ...}`
- Agent formats response in natural language

---

## Level 3: Understanding the Response

### Full Response Structure

```bash
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_greet.json | jq '.'
```

**Response breakdown:**

```json
{
  "jsonrpc": "2.0",
  "id": "test-greet",
  "result": {
    "artifacts": [
      {
        "parts": [{"kind": "text", "text": "The final answer"}]
      }
    ],
    "history": [
      {"role": "user", "parts": [...], "messageId": "msg-greet-1"},
      {"role": "agent", "parts": [{"kind": "data", "data": {"name": "greet_user", "args": {"name": "Vishal"}}}]},
      {"role": "agent", "parts": [{"kind": "data", "data": {"response": {"result": "Hello Vishal!..."}}}]},
      {"role": "agent", "parts": [{"kind": "text", "text": "Hello Vishal!..."}]}
    ],
    "metadata": {
      "adk_usage_metadata": {"totalTokenCount": 192, ...}
    },
    "status": {"state": "completed"}
  }
}
```

**Key parts:**
- `artifacts[0].parts[0].text` - **The actual answer** (what you want)
- `history` - Complete conversation trace showing:
  - Your message
  - Agent's tool call (function_call)
  - Tool's response (function_response)
  - Agent's final message
- `metadata.adk_usage_metadata` - Token usage from Gemini
- `status.state` - Task completion status

### Extract Just the Answer

```bash
# Get just the text response
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_greet.json 2>/dev/null | jq -r '.result.artifacts[0].parts[0].text'
```

### View Tool Calls

```bash
# See what tools were called
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_greet.json 2>/dev/null | \
  jq '.result.history[] | select(.parts[0].metadata.adk_type == "function_call") | .parts[0].data'
```

**Output:**
```json
{
  "id": "adk-xxxxx",
  "name": "greet_user",
  "args": {
    "name": "Vishal"
  }
}
```

This shows the agent decided to call `greet_user` with parameter `name="Vishal"`.

---

## Level 4: Interactive Python Testing

For more control, use Python:

```python
#!/usr/bin/env python3
"""Interactive test script for test agent"""
import httpx
import asyncio
from uuid import uuid4

GATEWAY_URL = "http://localhost:4000"
API_KEY = "sk-1234"
AGENT_NAME = "test_agent"

async def invoke_agent(message: str):
    """Send a message to the test agent"""
    url = f"{GATEWAY_URL}/a2a/{AGENT_NAME}/message/send"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": str(uuid4()),
        "method": "message/send",
        "params": {
            "message": {
                "role": "user",
                "parts": [{"kind": "text", "text": message}],
                "messageId": str(uuid4())
            }
        }
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(url, headers=headers, json=payload)
        result = response.json()

        if "result" in result:
            # Extract the answer
            answer = result["result"]["artifacts"][0]["parts"][0]["text"]
            print(f"\n✅ Agent Response:\n{answer}")

            # Show token usage
            metadata = result["result"]["metadata"]
            tokens = metadata["adk_usage_metadata"]["totalTokenCount"]
            print(f"\n📊 Tokens used: {tokens}")

            # Show tool calls
            history = result["result"]["history"]
            tool_calls = [
                h["parts"][0]["data"]
                for h in history
                if h.get("parts", [{}])[0].get("metadata", {}).get("adk_type") == "function_call"
            ]
            if tool_calls:
                print(f"\n🔧 Tools called:")
                for tool in tool_calls:
                    print(f"   - {tool['name']}({tool['args']})")
        else:
            print(f"\n❌ Error: {result.get('error', result)}")

async def main():
    print("=" * 60)
    print("Test Agent Interactive Tester")
    print("=" * 60)

    # Test 1: Greet
    print("\n[Test 1] Greeting")
    await invoke_agent("Hello! Can you greet me? My name is Vishal.")

    # Test 2: Status
    print("\n" + "=" * 60)
    print("\n[Test 2] Status Check")
    await invoke_agent("What is your current operational status?")

    # Test 3: General Question
    print("\n" + "=" * 60)
    print("\n[Test 3] General Question")
    await invoke_agent("What can you help me with?")

if __name__ == "__main__":
    asyncio.run(main())
```

Save as `test_agent_interactive.py` and run:

```bash
python3 test_agent_interactive.py
```

---

## Common Test Scenarios

### 1. Test Error Handling

```bash
# Invalid agent name
curl -X POST http://localhost:4000/a2a/nonexistent_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @/tmp/test_greet.json
```

**Expected:** Error about invalid agent name

### 2. Test Without Authentication

```bash
# Missing API key
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Content-Type: application/json" \
  -d @/tmp/test_greet.json
```

**Expected:** 401 Authentication Error

### 3. Test Agent Card Fetching

```bash
# Gateway fetches agent card from the agent
curl -s -H "Authorization: Bearer sk-1234" \
  http://localhost:4000/a2a/test_agent/.well-known/agent-card.json | jq '.'
```

**What happens:**
- Gateway proxies request to `http://test-agent:8090/.well-known/agent-card.json`
- Returns the agent's capabilities

---

## Debugging Tips

### View Gateway Logs

```bash
# See what the gateway is doing
docker logs agent-gateway --tail 50 -f
```

### View Agent Logs

```bash
# See what the agent is processing
docker logs test-agent --tail 50 -f
```

### Test Network Connectivity

```bash
# From gateway container, can it reach the agent?
docker exec agent-gateway python -c \
  "import urllib.request; print(urllib.request.urlopen('http://test-agent:8090/.well-known/agent-card.json').read().decode()[:200])"
```

**Expected:** Should return agent card JSON

### Check Agent Health

```bash
# Verify agent is responding
curl -s http://localhost:8090/.well-known/agent-card.json | jq '.name'
```

**Expected:** "TestAgent"

---

## Understanding A2A Protocol

### JSON-RPC Format

A2A uses JSON-RPC 2.0:

```json
{
  "jsonrpc": "2.0",           // Protocol version
  "id": "unique-request-id",  // Request ID (for matching responses)
  "method": "message/send",   // Method name (always "message/send" for A2A)
  "params": {
    "message": {
      "role": "user",         // Who sent the message
      "parts": [              // Message content (can be text, images, etc.)
        {"kind": "text", "text": "Your message here"}
      ],
      "messageId": "unique"   // Message ID (for threading)
    }
  }
}
```

### Response Format

```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",  // Matches request ID
  "result": {
    "artifacts": [...],       // Final outputs
    "history": [...],         // Conversation trace
    "metadata": {...},        // Usage stats, etc.
    "status": {...}           // Completion status
  }
}
```

---

## Next Steps

1. **Try different queries** - See how the agent responds to various requests
2. **Monitor logs** - Watch both gateway and agent logs to see the flow
3. **Modify the agent** - Add new tools to test_agent/agent.py and rebuild
4. **Apply to other agents** - Use this same pattern for OxygenAgent, etc.

---

## Quick Reference Commands

```bash
# Check agent status
docker ps | grep test-agent

# View agent card
curl http://localhost:8090/.well-known/agent-card.json | jq .

# List registered agents
curl -s -H "Authorization: Bearer sk-1234" http://localhost:4000/v1/agents | jq '.[] | .agent_name'

# Test invocation
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":"1","method":"message/send","params":{"message":{"role":"user","parts":[{"kind":"text","text":"Hello!"}],"messageId":"1"}}}' \
  | jq -r '.result.artifacts[0].parts[0].text'

# View logs
docker logs test-agent -f
docker logs agent-gateway -f
```
