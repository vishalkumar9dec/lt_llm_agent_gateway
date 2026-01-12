# Agent URL Requirements - The Truth

## Key Discovery

**You CAN'T just register any URL if the agent's card says something different!**

The LiteLLM gateway:
1. Accepts your registration with a URL
2. **BUT** when invoking, it fetches the agent card from the agent
3. Uses the URL from the **agent's own card**, ignoring what you registered

## When "Just Register URL" Works

✅ **Works when agent card has correct URL:**

```bash
# Agent card shows:
{
  "url": "https://my-agent.run.app"  # Publicly accessible
}

# You register:
url: "https://my-agent.run.app"

# ✅ Works! Gateway uses agent card URL which is correct
```

**Examples:**
- Cloud-deployed agents with public URLs
- Agents specifically configured for remote access
- Production agents with proper HOST_OVERRIDE set

## When It DOESN'T Work

❌ **Fails when agent card has wrong URL:**

```bash
# Agent card shows:
{
  "url": "http://0.0.0.0:8082"  # Not accessible!
}

# You register:
url: "http://host.docker.internal:8082"  # This is correct!

# ❌ Fails! Gateway ignores your URL, uses agent card's URL (0.0.0.0)
```

**Examples:**
- Agents running locally with `0.0.0.0` binding
- Agents without HOST_OVERRIDE configuration
- Development agents not configured for remote access

## The Solution

For agents advertising wrong URLs, you have 2 options:

### Option 1: Fix Agent Code

Modify the agent to use custom AgentCard:

```python
# In agent.py
import os
from a2a.types import AgentCard

PUBLIC_URL = os.getenv("HOST_OVERRIDE", "http://localhost:8082")

custom_agent_card = AgentCard(
    protocolVersion="1.0",
    name="MyAgent",
    url=PUBLIC_URL,  # Use environment variable!
    # ... other fields
)

a2a_app = to_a2a(
    agent,
    agent_card=custom_agent_card  # Pass custom card
)
```

Then start with:
```bash
HOST_OVERRIDE=http://host.docker.internal:8082 python agent.py
```

### Option 2: Dockerize It

Add to docker-compose.yml:

```yaml
services:
  my-agent:
    build: ./path/to/agent
    environment:
      HOST_OVERRIDE: "http://my-agent:8082"  # Docker service name
    networks:
      - agent-network
```

Gateway can reach it via: `http://my-agent:8082`

## Real-World Scenarios

### Scenario 1: Cloud-Deployed Agent ✅
```
Agent running on Cloud Run
Agent card URL: https://agent-xyz.run.app
Register: https://agent-xyz.run.app
Result: ✅ Works! (Agent card URL is correct and accessible)
```

### Scenario 2: Local Development Agent ❌
```
Agent running on host at port 8082
Agent card URL: http://0.0.0.0:8082
Register: http://host.docker.internal:8082
Result: ❌ Fails! (Agent card URL is wrong)
Fix: Modify agent code or dockerize
```

### Scenario 3: Agent in Different Docker ❌
```
Agent in separate docker-compose
Agent card URL: http://0.0.0.0:8082
Register: http://agent-container:8082
Result: ❌ Fails if networks not connected
Fix: Connect networks or fix agent card URL
```

### Scenario 4: Fixed Agent ✅
```
Agent with custom AgentCard and HOST_OVERRIDE
Agent card URL: http://host.docker.internal:8082
Register: http://host.docker.internal:8082
Result: ✅ Works! (URLs match)
```

## Decision Tree

```
Do you control the agent code?
├─ Yes
│  └─ Modify agent to use custom AgentCard with HOST_OVERRIDE
│     └─ Set HOST_OVERRIDE when starting
│        └─ ✅ Register with that URL
│
└─ No
   └─ Check agent's card URL
      ├─ Is it accessible from gateway?
      │  └─ Yes → ✅ Register that URL
      │  └─ No  → ❌ Can't use this agent
      │           (or dockerize both in same network)
```

## Testing Checklist

Before registering a remote agent:

1. **Check agent card:**
   ```bash
   curl http://agent-url/.well-known/agent-card.json | jq '.url'
   ```

2. **Test from gateway:**
   ```bash
   docker exec agent-gateway python -c "import urllib.request; print(urllib.request.urlopen('AGENT_CARD_URL').read()[:100])"
   ```

3. **If test passes:**
   - ✅ Register the URL from agent card
   - Should work!

4. **If test fails:**
   - ❌ Agent card URL is wrong
   - Fix agent code OR dockerize

## Summary

**The Simple Rule:**

> The URL in the agent's card must be accessible from the gateway.
>
> If it's not, you must either:
> - Fix the agent code to advertise correct URL
> - Put both in same Docker network

**You can't override an agent's advertised URL by just registering a different one!**

## Your Current Agents

### test-agent ✅
```
Status: Working
Reason: Custom AgentCard with HOST_OVERRIDE
Card URL: http://test-agent:8090
Location: Docker (same network as gateway)
```

### OxygenAgent ❌
```
Status: Not working as remote
Reason: Card advertises http://0.0.0.0:8082
Card URL: http://0.0.0.0:8082 (not accessible)
Location: Host machine (port 8082)
Fix needed: Add custom AgentCard or dockerize
```

### TicketsAgent ❌
```
Status: Not working as remote
Reason: Card advertises http://0.0.0.0:8080
Card URL: http://0.0.0.0:8080 (not accessible)
Location: Host machine (port 8080)
Fix needed: Add custom AgentCard or dockerize
```

## Next Steps

To make OxygenAgent and TicketsAgent work, follow:
- **DOCKERIZED_AGENT_SOLUTION.md** - Complete fix guide
