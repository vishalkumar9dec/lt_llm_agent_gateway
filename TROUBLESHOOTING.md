# A2A Agent Invocation Troubleshooting

## Current Status

✅ **Gateway Setup**: LiteLLM Gateway is running with A2A SDK installed
✅ **Agent Registration**: OxygenAgent is registered in the gateway
✅ **Network Connectivity**: Docker can reach the agent at `host.docker.internal:8082`
❌ **Invocation Failing**: Agent URL in agent card is `http://0.0.0.0:8082` which doesn't work from Docker

## Root Cause

The OxygenAgent's agent card advertises itself with URL `"url":"http://0.0.0.0:8082"`. When LiteLLM Gateway tries to invoke the agent, it reads the URL from the agent card and attempts to connect to `0.0.0.0:8082`, which fails because `0.0.0.0` is not routable.

### Agent Card URL Issue

```json
{
  "name": "OxygenAgent",
  "url": "http://0.0.0.0:8082",  ← This is the problem
  ...
}
```

## Solution

The agent needs to be configured to advertise a proper URL that is accessible from Docker containers.

### Option 1: Configure Agent to Use `host.docker.internal` (Recommended for local development)

In the `agentic_jarvis` project where OxygenAgent is defined, update the agent configuration to advertise:

```python
agent_url = "http://host.docker.internal:8082"  # For Mac/Windows Docker
# OR
agent_url = "http://172.17.0.1:8082"  # For Linux Docker
```

### Option 2: Use Machine's Actual IP Address

Find your machine's IP:
```bash
# Mac
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'
```

Then configure the agent to advertise:
```python
agent_url = "http://192.168.1.x:8082"  # Your actual IP
```

### Option 3: Run Agent in Docker on Same Network

If you dockerize the OxygenAgent and run it on the same Docker network as the gateway, use the service name:
```python
agent_url = "http://oxygen-agent:8082"  # Docker service name
```

## Testing After Fix

Once the agent is configured with the correct URL, restart it and test:

```bash
# 1. Verify agent card shows correct URL
curl http://localhost:8082/.well-known/agent-card.json | jq '.url'

# Expected: "http://host.docker.internal:8082" (not "http://0.0.0.0:8082")

# 2. Test invocation through gateway
curl -X POST http://localhost:4000/a2a/oxygen_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test-1",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "show learning summary for vishal"}],
        "messageId": "msg-1"
      }
    }
  }' | jq '.'
```

## Current Setup Details

### Gateway Configuration
- **URL**: http://localhost:4000
- **Admin UI**: http://localhost:4000/ui
- **Master Key**: sk-1234
- **Docker Container**: agent-gateway
- **A2A SDK**: Installed (version 0.3.22)

### Registered Agents
1. **oxygen_agent**
   - Name: OxygenAgent
   - Port: 8082
   - Issue: URL in agent card is `0.0.0.0:8082`

2. **tickets_agent**
   - Name: Jarvis Tickets agent
   - Port: 8080 (configured in database)
   - Status: Not tested yet

### Database
- **PostgreSQL**: Running in Docker (agent-gateway-postgres)
- **Table**: `LiteLLM_AgentsTable`
- **URL Column**: `agent_card_params->>'url'`

Note: The URL in the database (`host.docker.internal:8082`) is correct, but the gateway reads the URL from the agent card itself, not from the database.

## Next Steps

1. **Fix the OxygenAgent configuration** in the `agentic_jarvis` project:
   - Locate the agent configuration file
   - Update the URL to use `host.docker.internal:8082`
   - Restart the agent

2. **Verify the fix**:
   - Check agent card URL: `curl http://localhost:8082/.well-known/agent-card.json | jq '.url'`
   - Should show: `"http://host.docker.internal:8082"`

3. **Test invocation**:
   - Run the test script: `./fix_and_test_agent.sh`
   - Should get a successful response from the agent

4. **Test Tickets Agent** (if needed):
   - Ensure tickets agent is running in `agentic_jarvis`
   - Verify it has the correct URL in its agent card
   - Test invocation through gateway

## References

- [LiteLLM A2A Documentation](https://docs.litellm.ai/docs/a2a)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [Agent Gateway Architecture](./docs/AGENT_ARCHITECTURE.md)
