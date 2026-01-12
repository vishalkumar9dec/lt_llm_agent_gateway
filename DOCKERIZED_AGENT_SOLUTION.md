# Dockerized A2A Agent Solution

## Problem

When A2A agents run in Docker and LiteLLM gateway also runs in Docker, the agent card advertises `http://0.0.0.0:port` which the gateway cannot reach, causing "Cannot connect to host 0.0.0.0" errors.

## Solution

Deploy agents in the **same Docker network** as the gateway and configure the agent card to advertise the Docker service name URL.

## Tested & Working: test-agent ✅

Successfully tested with test-agent calling through LiteLLM gateway.

---

## Step-by-Step Implementation

### 1. Modify Agent Code

Add custom AgentCard with HOST_OVERRIDE support:

```python
"""
Example Agent Service
"""
import os
from google.adk.agents import LlmAgent
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from a2a.types import AgentCard

# Your agent tools here
def your_tool_function(param: str) -> str:
    """Tool description"""
    return f"Result: {param}"

# Create your agent
your_agent = LlmAgent(
    model="gemini-2.0-flash-exp",
    name="YourAgent",
    description="Your agent description",
    tools=[your_tool_function]
)

# Get the public URL from environment
PUBLIC_URL = os.getenv("HOST_OVERRIDE", "http://your-agent:8080")

# Build custom agent card with correct URL
custom_agent_card = AgentCard(
    protocolVersion="1.0",
    name="YourAgent",
    description="Your agent description",
    url=PUBLIC_URL,  # This is the key fix!
    version="1.0.0",
    defaultInputModes=["text/plain"],
    defaultOutputModes=["text/plain"],
    capabilities={},
    skills=[
        {
            "id": "your_tool_function",
            "name": "Your Tool",
            "description": "Tool description",
            "tags": ["tag1", "tag2"]
        }
    ]
)

# Expose via A2A protocol with custom agent card
a2a_app = to_a2a(
    your_agent,
    port=8080,
    host="0.0.0.0",
    agent_card=custom_agent_card  # Pass custom card
)
```

**Key Changes:**
- Import `AgentCard` from `a2a.types`
- Read `HOST_OVERRIDE` from environment
- Create custom `AgentCard` with correct URL
- Pass `agent_card=custom_agent_card` to `to_a2a()`

### 2. Update requirements.txt

Ensure you have both required packages:

```txt
google-adk>=1.22.0
a2a-sdk>=0.3.0
uvicorn>=0.27.0
python-dotenv>=1.0.0
```

### 3. Create Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY agent.py .

# Expose port
EXPOSE 8080

# Run the agent
CMD ["uvicorn", "agent:a2a_app", "--host", "0.0.0.0", "--port", "8080"]
```

### 4. Add to docker-compose.yml

Add your agent to the `agent-network`:

```yaml
services:
  # ... existing gateway and postgres services ...

  your-agent:
    build:
      context: ./your_agent_directory
      dockerfile: Dockerfile
    container_name: your-agent
    environment:
      GOOGLE_API_KEY: ${GOOGLE_API_KEY}
      HOST_OVERRIDE: "http://your-agent:8080"  # Docker service name!
    ports:
      - "8080:8080"
    networks:
      - agent-network  # Same network as gateway
    restart: unless-stopped
```

**Important:**
- `HOST_OVERRIDE` must use the Docker **service name** (e.g., `your-agent`), not `localhost` or `host.docker.internal`
- Use the same `agent-network` as the gateway

### 5. Build and Start

```bash
# Build the agent
docker-compose build your-agent

# Start the agent
docker-compose up -d your-agent

# Check logs
docker logs your-agent

# Verify agent card shows correct URL
curl http://localhost:8080/.well-known/agent-card.json | jq '.url'
# Should return: "http://your-agent:8080"
```

### 6. Register in LiteLLM Gateway

```bash
curl -X POST http://localhost:4000/v1/agents \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "your_agent",
    "agent_card_params": {
      "protocolVersion": "1.0",
      "name": "Your Agent",
      "description": "Your agent description",
      "url": "http://your-agent:8080",
      "version": "1.0.0",
      "defaultInputModes": ["text"],
      "defaultOutputModes": ["text"],
      "capabilities": {
        "streaming": false
      },
      "skills": []
    },
    "litellm_params": {
      "make_public": false
    }
  }'
```

**Important:** Use the Docker service name `http://your-agent:8080` (not `localhost`!)

### 7. Test Agent Invocation

```bash
curl -X POST http://localhost:4000/a2a/your_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test-1",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Hello agent!"}],
        "messageId": "msg-1"
      }
    }
  }' | jq '.result.artifacts[0].parts[0].text'
```

---

## Migrating Existing Agents

### For OxygenAgent (Port 8082)

1. **Modify** `/path/to/agentic_jarvis/oxygen_agent_service/agent.py`:
   - Add `from a2a.types import AgentCard`
   - Add custom AgentCard with `PUBLIC_URL = os.getenv("HOST_OVERRIDE", "http://oxygen-agent:8082")`
   - Pass `agent_card=custom_agent_card` to `to_a2a()`

2. **Create** `Dockerfile` in `oxygen_agent_service/` directory

3. **Add** to `docker-compose.yml`:
   ```yaml
   oxygen-agent:
     build:
       context: /path/to/agentic_jarvis/oxygen_agent_service
     container_name: oxygen-agent
     environment:
       GOOGLE_API_KEY: ${GOOGLE_API_KEY}
       HOST_OVERRIDE: "http://oxygen-agent:8082"
     ports:
       - "8082:8082"
     networks:
       - agent-network
     restart: unless-stopped
   ```

4. **Update** registration URL to `http://oxygen-agent:8082`

5. **Rebuild** and test

---

## Verification Checklist

- [ ] Agent code imports `AgentCard` from `a2a.types`
- [ ] Custom AgentCard created with `url=os.getenv("HOST_OVERRIDE", ...)`
- [ ] `agent_card` parameter passed to `to_a2a()`
- [ ] `a2a-sdk` added to requirements.txt
- [ ] Dockerfile created
- [ ] Service added to docker-compose.yml with:
  - [ ] `HOST_OVERRIDE` environment variable (using service name)
  - [ ] Same `agent-network` as gateway
  - [ ] Correct port mapping
- [ ] Agent card URL check: `curl http://localhost:PORT/.well-known/agent-card.json | jq '.url'`
  - Should return Docker service name URL, not `0.0.0.0`
- [ ] Agent registered in gateway with Docker service name URL
- [ ] Test invocation through gateway works

---

## Why This Works

1. **Docker Networking**: Services in the same Docker network can communicate using service names as DNS
2. **Custom Agent Card**: Explicitly sets the URL that clients should use to reach the agent
3. **HOST_OVERRIDE**: Allows different URLs for different environments (local dev, docker, cloud)

## Common Issues

### Issue: Still getting "Cannot connect to host 0.0.0.0"
**Solution**: Agent card is still advertising 0.0.0.0. Ensure:
- Custom AgentCard is created
- `agent_card=custom_agent_card` is passed to `to_a2a()`
- Agent was restarted after code changes

### Issue: Connection refused to service-name:port
**Solution**: Services not in same network. Ensure:
- Both gateway and agent have `networks: - agent-network`
- Network name matches exactly

### Issue: Cannot resolve service-name
**Solution**: Using wrong URL. Must use Docker service name from `container_name`, not localhost or host.docker.internal

---

## Test Agent Example

See `/Users/vishalkumar/projects/agent_gateway/test_agent/` for a complete working example.

**Test it:**
```bash
# Check agent card
curl http://localhost:8090/.well-known/agent-card.json | jq '.url'

# Invoke through gateway
curl -X POST http://localhost:4000/a2a/test_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d @test_payload.json
```

---

## References

- [Google ADK A2A Documentation](https://google.github.io/adk-docs/a2a/)
- [Deploy A2A agents to Cloud Run](https://cloud.google.com/run/docs/deploy-a2a-agents)
- [HOST_OVERRIDE environment variable usage](https://cloud.google.com/run/docs/deploy-a2a-agents)
- [A2A Protocol Specification](https://a2a-protocol.org/)

---

**Last Updated**: January 12, 2026
**Status**: ✅ Solution Tested and Working
