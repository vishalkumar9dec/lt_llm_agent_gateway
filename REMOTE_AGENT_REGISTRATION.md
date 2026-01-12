# Registering Remote Agents (When You Just Have the URL)

## Overview

When an agent runs **outside** your docker-compose setup, you just need:
1. The agent's URL
2. Ability for the gateway to reach that URL
3. Register it in LiteLLM

**No Dockerfile or docker-compose changes needed!**

---

## Scenario 1: Agent Running on Host Machine (Outside Docker)

### Example: OxygenAgent running on your laptop

```bash
# Agent is running on your machine at port 8082
# You started it with: python agent.py
ps aux | grep oxygen
# → Shows agent running on port 8082
```

### Gateway Access

From inside Docker, the gateway needs to use `host.docker.internal`:

```bash
# Test connectivity from gateway
docker exec agent-gateway python -c \
  "import urllib.request; \
   print(urllib.request.urlopen('http://host.docker.internal:8082/.well-known/agent-card.json').read().decode()[:100])"
```

### Registration

```bash
curl -X POST http://localhost:4000/v1/agents \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "oxygen_agent",
    "agent_card_params": {
      "protocolVersion": "1.0",
      "name": "Oxygen Agent",
      "description": "Learning platform agent",
      "url": "http://host.docker.internal:8082",
      "version": "1.0.0",
      "defaultInputModes": ["text"],
      "defaultOutputModes": ["text"],
      "capabilities": {"streaming": false},
      "skills": []
    },
    "litellm_params": {"make_public": false}
  }'
```

**Key:** Use `http://host.docker.internal:8082` (not `localhost`)

### Test

```bash
curl -X POST http://localhost:4000/a2a/oxygen_agent/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Show courses for vishal"}],
        "messageId": "msg-1"
      }
    }
  }' | jq -r '.result.artifacts[0].parts[0].text'
```

---

## Scenario 2: Agent on Different Machine (Same Network)

### Example: Agent on another laptop/server in your network

```bash
# Agent is running on another machine
# Machine IP: 192.168.1.50
# Port: 8082
```

### Gateway Access

Use the actual IP address:

```bash
# Test connectivity from gateway
docker exec agent-gateway python -c \
  "import urllib.request; \
   print(urllib.request.urlopen('http://192.168.1.50:8082/.well-known/agent-card.json').read().decode()[:100])"
```

### Registration

```bash
curl -X POST http://localhost:4000/v1/agents \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "remote_oxygen_agent",
    "agent_card_params": {
      "protocolVersion": "1.0",
      "name": "Remote Oxygen Agent",
      "description": "Learning platform agent on remote server",
      "url": "http://192.168.1.50:8082",
      "version": "1.0.0",
      "defaultInputModes": ["text"],
      "defaultOutputModes": ["text"],
      "capabilities": {"streaming": false},
      "skills": []
    },
    "litellm_params": {"make_public": false}
  }'
```

**Key:** Use actual IP address `http://192.168.1.50:8082`

### Important Considerations

1. **Firewall:** Make sure the remote machine's firewall allows connections on that port
2. **Network:** Both machines must be on the same network or have routing configured
3. **Agent binding:** The agent must bind to `0.0.0.0` (not just `127.0.0.1`) to accept external connections

---

## Scenario 3: Agent in Cloud (Public URL)

### Example: Agent deployed to Google Cloud Run

```bash
# Agent is deployed to cloud with public URL
# URL: https://oxygen-agent-abc123.run.app
```

### Gateway Access

Use the public HTTPS URL directly:

```bash
# Test connectivity from gateway
docker exec agent-gateway python -c \
  "import urllib.request; \
   print(urllib.request.urlopen('https://oxygen-agent-abc123.run.app/.well-known/agent-card.json').read().decode()[:100])"
```

### Registration

```bash
curl -X POST http://localhost:4000/v1/agents \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "cloud_oxygen_agent",
    "agent_card_params": {
      "protocolVersion": "1.0",
      "name": "Cloud Oxygen Agent",
      "description": "Learning platform agent (Cloud Run)",
      "url": "https://oxygen-agent-abc123.run.app",
      "version": "1.0.0",
      "defaultInputModes": ["text"],
      "defaultOutputModes": ["text"],
      "capabilities": {"streaming": false},
      "skills": []
    },
    "litellm_params": {"make_public": false}
  }'
```

**Key:** Use full HTTPS URL

### Advantages

- ✅ No Docker networking issues
- ✅ Works from anywhere
- ✅ Scalable and production-ready

---

## Scenario 4: Agent in Separate Docker Network

### Example: Agent running in different docker-compose project

```bash
# Agent is in another docker-compose setup
# Network: agentic_jarvis_default
# Container: oxygen-agent
```

### Option A: Connect Gateway to Agent's Network

```yaml
# In agent_gateway/docker-compose.yml
services:
  gateway:
    networks:
      - agent-network
      - agentic_jarvis_default  # Add agent's network

networks:
  agent-network:
    driver: bridge
  agentic_jarvis_default:
    external: true  # Reference external network
```

Then register with container name:
```bash
curl -X POST http://localhost:4000/v1/agents \
  ... "url": "http://oxygen-agent:8082" ...
```

### Option B: Expose Agent Port and Use host.docker.internal

If agent exposes port to host (e.g., `-p 8082:8082`), use:
```bash
curl -X POST http://localhost:4000/v1/agents \
  ... "url": "http://host.docker.internal:8082" ...
```

---

## Quick Decision Matrix

| Agent Location | URL Format | Example |
|---|---|---|
| Same docker-compose | `http://service-name:port` | `http://test-agent:8090` |
| Host machine (outside Docker) | `http://host.docker.internal:port` | `http://host.docker.internal:8082` |
| Different machine (local network) | `http://IP:port` | `http://192.168.1.50:8082` |
| Cloud (public URL) | `https://domain` | `https://agent.run.app` |
| Different Docker network | Connect networks OR `host.docker.internal` | (see Scenario 4) |

---

## Registration Template

Generic template for any remote agent:

```bash
#!/bin/bash
# register_remote_agent.sh

AGENT_NAME="your_agent"
AGENT_URL="http://agent-url:port"  # Change this!
AGENT_DISPLAY_NAME="Your Agent"
AGENT_DESCRIPTION="Agent description"

curl -X POST http://localhost:4000/v1/agents \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d "{
    \"agent_name\": \"${AGENT_NAME}\",
    \"agent_card_params\": {
      \"protocolVersion\": \"1.0\",
      \"name\": \"${AGENT_DISPLAY_NAME}\",
      \"description\": \"${AGENT_DESCRIPTION}\",
      \"url\": \"${AGENT_URL}\",
      \"version\": \"1.0.0\",
      \"defaultInputModes\": [\"text\"],
      \"defaultOutputModes\": [\"text\"],
      \"capabilities\": {\"streaming\": false},
      \"skills\": []
    },
    \"litellm_params\": {\"make_public\": false}
  }" | jq '.'
```

---

## Testing Remote Agent Connection

### Step 1: Test from your machine

```bash
# Can you reach the agent card?
curl http://AGENT_URL/.well-known/agent-card.json
```

### Step 2: Test from gateway container

```bash
# Can the gateway reach the agent?
docker exec agent-gateway python -c \
  "import urllib.request; \
   print(urllib.request.urlopen('http://AGENT_URL/.well-known/agent-card.json').read().decode()[:200])"
```

### Step 3: Register the agent

Use the URL that works from Step 2!

### Step 4: Test invocation

```bash
curl -X POST http://localhost:4000/a2a/AGENT_NAME/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Test message"}],
        "messageId": "test-1"
      }
    }
  }' | jq '.'
```

---

## Common Issues

### Issue: "Cannot connect to host"

**Diagnosis:**
```bash
# Test from gateway
docker exec agent-gateway curl -v http://AGENT_URL/.well-known/agent-card.json
```

**Solutions:**
- If "Could not resolve host": Wrong URL or hostname
- If "Connection refused": Port not open or agent not running
- If "Connection timeout": Firewall blocking or wrong network

### Issue: Gateway can't reach `localhost:8082`

**Problem:** Used `localhost` in URL but agent is not in gateway container

**Solution:** Use correct URL:
- Host machine → `host.docker.internal:8082`
- Another machine → `192.168.1.x:8082`
- Cloud → `https://your-agent.com`

### Issue: Agent card shows wrong URL

**Problem:** Agent card advertises `http://0.0.0.0:port` or `http://localhost:port`

**Solution:**
1. If you control the agent code, fix the agent card URL (use custom AgentCard)
2. If you don't control the agent, the gateway will still try to use the registered URL you provided

---

## Real-World Example: Register OxygenAgent Running Locally

Currently, OxygenAgent is probably running on your host machine at port 8082.

### Check if it's running:
```bash
curl http://localhost:8082/.well-known/agent-card.json | jq '{name, url}'
```

### Test gateway can reach it:
```bash
docker exec agent-gateway python -c \
  "import urllib.request; \
   print(urllib.request.urlopen('http://host.docker.internal:8082/.well-known/agent-card.json').read().decode()[:100])"
```

### Register it:
```bash
curl -X POST http://localhost:4000/v1/agents \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "oxygen_agent_host",
    "agent_card_params": {
      "protocolVersion": "1.0",
      "name": "Oxygen Agent",
      "description": "Learning platform agent",
      "url": "http://host.docker.internal:8082",
      "version": "1.0.0",
      "defaultInputModes": ["text"],
      "defaultOutputModes": ["text"],
      "capabilities": {"streaming": false},
      "skills": []
    },
    "litellm_params": {"make_public": false}
  }' | jq '.'
```

### Test it:
```bash
curl -X POST http://localhost:4000/a2a/oxygen_agent_host/message/send \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": "test",
    "method": "message/send",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "Show courses for vishal"}],
        "messageId": "msg-1"
      }
    }
  }' | jq -r '.result.artifacts[0].parts[0].text'
```

---

## Summary

**The Key Point:** When you have just a URL:

1. **No code changes needed** in your agent_gateway project
2. **No Dockerfile needed**
3. **No docker-compose changes needed**
4. Just **register** the agent with its URL
5. Make sure the **gateway can reach** that URL

The only difference from our test-agent example is:
- test-agent: Built and run in our docker-compose (URL: `http://test-agent:8090`)
- Remote agent: Running elsewhere (URL: whatever you're given)

**Gateway doesn't care where the agent is, as long as it can reach the URL!**
