# Test Agent - Quick Start Guide

## 🚀 Three Ways to Test

### 1. Quick Automated Tests (Fastest)
```bash
./quick_tests.sh
```
Runs 5 automated tests in seconds to verify everything works.

### 2. Interactive Python Script (Best for Learning)
```bash
python3 test_agent_interactive.py
```
Choose from:
- Automated test suite (shows tool usage, tokens, conversation flow)
- Interactive mode (ask your own questions)
- Quick single test

### 3. Manual curl Commands (Best for Understanding)
```bash
# Simple greeting test
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test-1",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Hi! Greet me, my name is Vishal"}],
        "messageId": "msg-1"
      }
    }
  }' | jq -r '.result.artifacts[0].parts[0].text'
```

---

## 📖 Detailed Guides

- **`MANUAL_TESTING_GUIDE.md`** - Complete manual testing walkthrough
- **`DOCKERIZED_AGENT_SOLUTION.md`** - How to replicate for other agents

---

## 🔍 What to Look For

### When Testing Works ✅
```
✅ Agent Response:
Hello Vishal! I'm the Test Agent, nice to meet you!

🔧 Tools Called:
   [1] greet_user()
       Args: {'name': 'Vishal'}
```

**This shows:**
1. Request reached the gateway
2. Gateway routed to test_agent
3. Agent's LLM understood the request
4. Agent called the `greet_user("Vishal")` tool
5. Tool executed and returned result
6. Agent formatted natural language response
7. Response returned through gateway

### The Flow
```
You
 └─> LiteLLM Gateway (port 4000)
      └─> Test Agent (port 8090, Docker network)
           └─> Gemini Model + Tools
                └─> greet_user() or get_status()
```

---

## 🧪 Test Commands

### Check Status
```bash
# Is agent running?
docker ps | grep test-agent

# View logs
docker logs test-agent --tail 20

# Check agent card
curl http://localhost:8090/.well-known/agent-card.json | jq '.'
```

### Test Through Gateway
```bash
# List all agents
curl -s -H "Authorization: Bearer sk-1234" \
  http://localhost:4000/v1/agents | jq '.[] | .agent_name'

# Test greeting (should call greet_user tool)
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @test_payload.json | jq -r '.result.artifacts[0].parts[0].text'

# Test status (should call get_status tool)
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":"1",
    "method":"message/send",
    "params":{
      "message":{
        "role":"user",
        "parts":[{"kind":"text","text":"What is your status?"}],
        "messageId":"1"
      }
    }
  }' | jq -r '.result.artifacts[0].parts[0].text'
```

---

## 🎯 Understanding the Response

### Full Response Structure
```json
{
  "jsonrpc": "2.0",
  "id": "test-1",
  "result": {
    "artifacts": [
      {
        "parts": [
          {"kind": "text", "text": "Hello Vishal! I'm the Test Agent..."}
        ]
      }
    ],
    "history": [
      // Shows the complete conversation including tool calls
    ],
    "metadata": {
      "adk_usage_metadata": {
        "totalTokenCount": 192  // Tokens used by Gemini
      }
    },
    "status": {
      "state": "completed"  // Task completed successfully
    }
  }
}
```

### Extract Specific Parts
```bash
# Just the answer
jq -r '.result.artifacts[0].parts[0].text'

# Token usage
jq '.result.metadata.adk_usage_metadata.totalTokenCount'

# Status
jq '.result.status.state'

# Tool calls
jq '.result.history[] | select(.parts[0].metadata.adk_type == "function_call")'
```

---

## 🛠️ Available Tools

The test agent has two tools:

### 1. greet_user(name: str)
```python
def greet_user(name: str) -> str:
    """Greet a user by name"""
    return f"Hello {name}! I'm the Test Agent, nice to meet you!"
```

**Trigger with:** "Greet me, my name is X"

### 2. get_status()
```python
def get_status() -> dict:
    """Get agent status"""
    return {
        "status": "healthy",
        "agent": "TestAgent",
        "version": "1.0.0",
        "message": "All systems operational"
    }
```

**Trigger with:** "What is your status?"

---

## 🐛 Debugging

### Agent not responding?
```bash
# Check if running
docker ps | grep test-agent

# Check logs for errors
docker logs test-agent

# Restart
docker-compose restart test-agent
```

### Gateway can't reach agent?
```bash
# Test from gateway container
docker exec agent-gateway python -c "import urllib.request; print(urllib.request.urlopen('http://test-agent:8090/.well-known/agent-card.json').read().decode()[:100])"

# Should return agent card JSON
```

### Agent card shows wrong URL?
```bash
# Check the URL
curl http://localhost:8090/.well-known/agent-card.json | jq '.url'

# Should be: "http://test-agent:8090"
# NOT: "http://0.0.0.0:8090"

# If wrong, check HOST_OVERRIDE in docker-compose.yml
```

---

## 📚 Next Steps

1. **Experiment** - Try different questions, see how the agent responds
2. **Monitor** - Watch logs while testing: `docker logs test-agent -f`
3. **Modify** - Add new tools to `test_agent/agent.py` and rebuild
4. **Replicate** - Apply same pattern to OxygenAgent using `DOCKERIZED_AGENT_SOLUTION.md`

---

## 🎓 Learning Points

### Key Takeaways:
1. **Docker Networking** - Agents use service names (`test-agent:8090`) not `localhost`
2. **Agent Card** - Must advertise correct URL for gateway to reach it
3. **A2A Protocol** - JSON-RPC 2.0 format for agent communication
4. **Tool Calling** - LLM decides when to call tools based on user request
5. **Gateway Routing** - Gateway looks up agent and forwards requests

### Why This Works Now:
- ✅ Agent runs in Docker with gateway
- ✅ Custom AgentCard with correct URL
- ✅ HOST_OVERRIDE environment variable set
- ✅ Same Docker network (`agent-network`)
- ✅ Gateway can reach agent via service name
