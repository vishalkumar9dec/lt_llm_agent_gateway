# Agent Gateway Architecture

## Overview

This document describes the **separation of concerns** architecture for LiteLLM Agent Gateway and A2A agents.

**Core Principle**: The gateway and agents are **separate, independent projects** that communicate via the A2A protocol. Agents are NOT embedded in the gateway codebase.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                       Your Machine                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐        ┌────────────────────┐    │
│  │  agent_gateway       │        │  agentic_jarvis    │    │
│  │  (This Project)      │        │  (Separate Repo)   │    │
│  │                      │        │                    │    │
│  │  ┌────────────┐      │        │  ┌──────────────┐ │    │
│  │  │ PostgreSQL │      │        │  │   Tickets    │ │    │
│  │  │   :5432    │      │        │  │    Agent     │ │    │
│  │  └─────┬──────┘      │        │  │   :8080      │ │    │
│  │        │             │        │  └──────┬───────┘ │    │
│  │  ┌─────▼──────┐      │        │         │         │    │
│  │  │  LiteLLM   │◄─────┼────────┼─────────┘         │    │
│  │  │  Gateway   │ A2A  │        │                    │    │
│  │  │   :4000    │      │        │  (Can run other    │    │
│  │  └────────────┘      │        │   agents too)      │    │
│  │                      │        │                    │    │
│  └──────────────────────┘        └────────────────────┘    │
│           │                              │                  │
│           │ Admin UI                     │ Agent URLs       │
│           ▼                              ▼                  │
│    http://localhost:4000/ui   http://localhost:8080        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Why This Architecture?

### ✅ Benefits of Separation

1. **Independent Development**
   - Update agents without touching gateway
   - Version agents independently
   - Different teams can own different agents

2. **True Microservices**
   - Each agent is a standalone service
   - Gateway is platform-agnostic (A2A protocol)
   - No tight coupling

3. **Reusability**
   - One agent can serve multiple gateways
   - Agents can be shared across projects
   - Easy to deploy agents to different environments

4. **Clean Code Organization**
   - `agent_gateway`: Infrastructure (routing, auth, logging)
   - `agentic_jarvis`: Business logic (agents, tools, data)
   - Clear separation of concerns

5. **Flexible Deployment**
   - Run gateway in Docker, agents on host
   - Or both in Docker (separate compose files)
   - Or deploy agents to cloud, gateway locally
   - Mix and match as needed

### ❌ Why NOT Embed Agents in Gateway

1. **Tight Coupling**: Changes to agents require gateway rebuild
2. **Code Duplication**: Multiple gateways need copies of the same agent
3. **Poor Scalability**: Can't scale agents independently
4. **Violates A2A Philosophy**: Protocol is designed for distributed agents

## Project Structure

### agent_gateway (This Project)

```
agent_gateway/
├── .env                    # Gateway environment variables
├── config.yaml             # Gateway configuration (model_list is empty)
├── docker-compose.yml      # PostgreSQL + LiteLLM Gateway only
├── start_all.sh           # Start gateway services
├── docs/
│   ├── AGENT_ARCHITECTURE.md   # This file
│   └── prompts.md
└── README.md
```

**Responsibility**: Provide routing, authentication, logging, and admin UI for agents.

### agentic_jarvis (Separate Project)

```
agentic_jarvis/
├── tickets_agent_service/
│   ├── agent.py           # Tickets Agent implementation
│   ├── requirements.txt
│   └── start.sh
├── finops_agent_service/
│   └── ...
└── oxygen_agent_service/
    └── ...
```

**Responsibility**: Implement agent business logic, tools, and data management.

## How It Works

### 1. Gateway Setup (One-Time)

```bash
cd agent_gateway
./start_all.sh
```

This starts:
- PostgreSQL (port 5432)
- LiteLLM Gateway (port 4000)

### 2. Agent Setup (Per Agent)

```bash
cd ../agentic_jarvis/tickets_agent_service
python agent.py
```

This starts the Tickets Agent on port 8080.

### 3. Register Agent via Admin UI

1. Open http://localhost:4000/ui
2. Navigate to "Agents" tab
3. Click "Add Agent"
4. Enter:
   - **Name**: `tickets_agent`
   - **URL**: `http://host.docker.internal:8080`

### 4. Use Agent

```bash
curl -X POST http://localhost:4000/chat/completions \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tickets_agent",
    "messages": [{"role": "user", "content": "show all tickets"}]
  }'
```

## Network Configuration

### Problem: Docker Networking

When the gateway runs in Docker and the agent runs on your host machine, `localhost` doesn't work because:
- From inside the Docker container, `localhost` refers to the container itself
- The agent is running on the **host machine**, not in the container

### Solution: Use `host.docker.internal`

On **Mac** and **Windows** Docker Desktop:

```
Agent URL: http://host.docker.internal:8080
```

This special DNS name resolves to your host machine's IP from within Docker containers.

On **Linux**:

```
Agent URL: http://172.17.0.1:8080
```

Or add `--add-host=host.docker.internal:host-gateway` to docker run command.

### Alternative: Use Actual IP Address

Find your machine's IP:

```bash
# Mac
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'

# Windows
ipconfig | findstr IPv4
```

Then use: `http://YOUR_IP:8080`

## Configuration Reference

### Gateway Configuration (config.yaml)

```yaml
model_list: []  # Empty - agents registered via Admin UI

litellm_settings:
  set_verbose: true
  enable_a2a: true  # Required for A2A protocol

general_settings:
  ui: true  # Enable Admin UI
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  store_model_in_db: true
  port: 4000
```

### Agent Registration (via UI)

- **Name**: Unique identifier (e.g., `tickets_agent`)
- **URL**: A2A invocation endpoint
  - Local agent: `http://host.docker.internal:PORT`
  - Remote agent: `http://agent-server.example.com:PORT`
  - Cloud agent: `https://agents.example.com/tickets`

### Environment Variables

**agent_gateway/.env:**

```bash
# Gateway Authentication
LITELLM_MASTER_KEY=sk-1234

# PostgreSQL
POSTGRES_USER=litellm
POSTGRES_PASSWORD=litellm
POSTGRES_DB=litellm
DATABASE_URL=postgresql://litellm:litellm@postgres:5432/litellm
```

**agentic_jarvis/.env** (agent-specific):

```bash
# Google API Key (for agents using Gemini)
GOOGLE_API_KEY=your_google_api_key_here

# Agent Configuration
AGENT_PORT=8080
AGENT_HOST=0.0.0.0
```

## Deployment Scenarios

### Scenario 1: Local Development (Current Setup)

```
Gateway: Docker (port 4000)
Agents:  Host machine (port 8080, 8081, ...)
```

**Pros**: Easy debugging, fast agent iteration
**Agent URL**: `http://host.docker.internal:8080`

### Scenario 2: All Docker

```bash
# In agentic_jarvis, create docker-compose.yml
# Use shared Docker network
```

**Pros**: Consistent environment, portable
**Agent URL**: `http://tickets-agent:8080` (service name)

### Scenario 3: Cloud Agents

```
Gateway: Local Docker
Agents:  Deployed to cloud (GCP, AWS, etc.)
```

**Pros**: Production-like setup, scalable agents
**Agent URL**: `https://agents.yourcompany.com/tickets`

### Scenario 4: Gateway in Cloud

```
Gateway: Deployed to Kubernetes
Agents:  Separate microservices in same cluster
```

**Pros**: Full production setup
**Agent URL**: `http://tickets-agent.agents.svc.cluster.local:8080`

## Testing

### Test Gateway Health

```bash
curl -H "Authorization: Bearer sk-1234" \
  http://localhost:4000/health
```

**Expected**:
```json
{"healthy_endpoints": [], "unhealthy_endpoints": [], ...}
```

### Test Agent Directly (Bypass Gateway)

```bash
curl http://localhost:8080/.well-known/agent-card.json
```

**Expected**: Agent card JSON with name, description, skills

### Test Agent via Gateway

```bash
curl -X POST http://localhost:4000/chat/completions \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "tickets_agent",
    "messages": [{"role": "user", "content": "show all tickets"}]
  }' | jq -r '.choices[0].message.content'
```

**Expected**: Agent response with ticket data

### Verify Agent Registration

```bash
curl -H "Authorization: Bearer sk-1234" \
  http://localhost:4000/v1/models | \
  jq '.data[] | select(.id == "tickets_agent")'
```

**Expected**: tickets_agent model details

## Troubleshooting

### Issue: Gateway can't reach agent

**Symptoms**:
```
Connection refused to http://localhost:8080
```

**Diagnosis**:
- Agent is running on host, gateway in Docker
- `localhost` inside container != `localhost` on host

**Solution**:
- Use `http://host.docker.internal:8080` (Mac/Windows)
- Or use your machine's IP: `http://192.168.1.x:8080`

### Issue: Agent not showing in gateway

**Symptoms**:
- Added agent via UI but not in `/v1/models`

**Diagnosis**:
- Check Admin UI for error messages
- Verify agent URL is accessible from Docker container

**Solution**:
```bash
# Test connectivity from inside gateway container
docker exec agent-gateway curl http://host.docker.internal:8080/.well-known/agent-card.json

# Should return agent card JSON
```

### Issue: Agent card not accessible

**Symptoms**:
```
404 Not Found on /.well-known/agent-card.json
```

**Diagnosis**:
- Agent not running
- Agent running on wrong port
- Agent doesn't expose A2A endpoints

**Solution**:
```bash
# Check agent is running
ps aux | grep agent.py

# Check agent logs
# Look for "Started server process" and port number
```

### Issue: Authentication errors

**Symptoms**:
```
{"error": "Authentication Error, No api key passed in."}
```

**Diagnosis**:
- Missing Authorization header
- Wrong API key

**Solution**:
```bash
# Use correct master key from .env
curl -H "Authorization: Bearer sk-1234" ...
```

## Best Practices

### 1. Environment Management

- **Never commit** `.env` files to git
- Use `.env.example` as template
- Document required variables in README

### 2. Port Allocation

Assign unique ports to each agent:

| Service | Port | Project |
|---------|------|---------|
| Gateway | 4000 | agent_gateway |
| Tickets Agent | 8080 | agentic_jarvis |
| FinOps Agent | 8081 | agentic_jarvis |
| Oxygen Agent | 8082 | agentic_jarvis |
| Auth Service | 9998 | shared_services |

### 3. Agent Naming

Use consistent naming:
- **Service name**: `tickets_agent_service`
- **Agent name in gateway**: `tickets_agent`
- **Container name** (if Dockerized): `tickets-agent`

### 4. Version Management

Tag agent versions in gateway UI:
- Development: `tickets_agent` → `http://localhost:8080`
- Staging: `tickets_agent_staging` → `http://staging.agents.com/tickets`
- Production: `tickets_agent_prod` → `https://agents.yourcompany.com/tickets`

### 5. Monitoring

Set up health checks:

```bash
# Gateway health
curl http://localhost:4000/health

# Agent health (via agent card)
curl http://localhost:8080/.well-known/agent-card.json

# Database health
docker exec agent-gateway-postgres pg_isready -U litellm
```

## Adding More Agents

To add additional agents (e.g., FinOps, Oxygen):

1. **Develop agent** in `agentic_jarvis` project
   ```bash
   cd agentic_jarvis/finops_agent_service
   python agent.py  # Runs on port 8081
   ```

2. **Register in gateway** via Admin UI
   - Name: `finops_agent`
   - URL: `http://host.docker.internal:8081`

3. **Test**
   ```bash
   curl -X POST http://localhost:4000/chat/completions \
     -H "Authorization: Bearer sk-1234" \
     -H "Content-Type: application/json" \
     -d '{"model": "finops_agent", "messages": [...]}'
   ```

No changes needed to `agent_gateway` project!

## Migration Path

If you previously had agents embedded in the gateway:

1. ✅ **Remove** `agents/` directory from agent_gateway
2. ✅ **Remove** agent services from `docker-compose.yml`
3. ✅ **Update** `start_all.sh` to remove agent references
4. ✅ **Move** agent code to `agentic_jarvis` project
5. **Start** agents independently in agentic_jarvis
6. **Register** agents via Admin UI using `host.docker.internal`

## References

- [LiteLLM A2A Documentation](https://docs.litellm.ai/docs/a2a)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [Google ADK Documentation](https://google.github.io/adk-docs/)
- [agentic_jarvis Repository](https://github.com/vishalkumar9dec/agentic_jarvis)

## Quick Command Reference

```bash
# Start gateway
cd agent_gateway && ./start_all.sh

# Start tickets agent (in separate terminal)
cd agentic_jarvis/tickets_agent_service && python agent.py

# View gateway logs
cd agent_gateway && docker-compose logs -f

# Stop gateway
cd agent_gateway && docker-compose down

# Test agent registration
curl -H "Authorization: Bearer sk-1234" \
  http://localhost:4000/v1/models | jq '.data[].id'

# Test agent directly
curl http://localhost:8080/.well-known/agent-card.json | jq .

# Test agent via gateway
curl -X POST http://localhost:4000/chat/completions \
  -H "Authorization: Bearer sk-1234" \
  -H "Content-Type: application/json" \
  -d '{"model":"tickets_agent","messages":[{"role":"user","content":"test"}]}' \
  | jq -r '.choices[0].message.content'
```

---

**Last Updated**: January 2026
**Architecture Version**: 2.0 (Separated Architecture)
