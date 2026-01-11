# LiteLLM Agent Gateway

An agent gateway built on LiteLLM's A2A (Agent-to-Agent) protocol for managing and orchestrating multiple AI agents.

## Overview

This project implements a minimal LiteLLM Agent Gateway with a built-in Admin UI for adding, editing, and deleting agents. The gateway supports the A2A protocol for agent communication and provides a centralized interface for agent management.

## Features

- Agent management UI (add/edit/delete agents)
- A2A protocol support for agent-to-agent communication
- PostgreSQL database for storing agent configurations, users, and permissions
- RESTful API for agent invocation
- Admin authentication with master key
- Persistent storage for agents and configurations

## Prerequisites

- Python 3.13.5 (or compatible version)
- PostgreSQL 15+ (installed via Homebrew)
- Virtual environment (`.venv` already set up)

## Installation

1. Install dependencies:
```bash
source .venv/bin/activate
pip install -r requirements.txt
```

2. Set up PostgreSQL (if not already running):
```bash
brew services start postgresql@15
/opt/homebrew/opt/postgresql@15/bin/createdb litellm
```

3. Configure environment variables:
   - The `.env` file is pre-configured with:
     - `LITELLM_MASTER_KEY=sk-1234` (change for production)
     - `DATABASE_URL=postgresql://vishalkumar@localhost:5432/litellm`
   - Update these values as needed for your environment

4. Review `config.yaml`:
   - The gateway is configured to run on port 4000
   - Admin UI is enabled by default
   - PostgreSQL database connection is configured

## Running the Gateway

Start the LiteLLM gateway:

```bash
source .venv/bin/activate
litellm --config config.yaml
```

The gateway will:
- Start on `http://localhost:4000`
- Run PostgreSQL migrations automatically
- Initialize all necessary database tables
- Enable the Admin UI at `http://localhost:4000/ui`

## Accessing the Admin UI

1. Open your browser and navigate to: `http://localhost:4000/ui`
2. You may need to authenticate with the master key from `.env`
3. Navigate to the "Agents" tab to manage agents

## API Endpoints

- `GET /health` - Health check endpoint
- `GET /v1/agents` - List all available agents
- `POST /v1/agents` - Add a new agent (via Admin UI)
- Agent invocation endpoints (depends on configured agents)

## Configuration

### Environment Variables (.env)

- `LITELLM_MASTER_KEY`: Master key for admin authentication (default: `sk-1234`)
- `DATABASE_URL`: PostgreSQL connection string (format: `postgresql://user@host:port/database`)
- `ENVIRONMENT`: Development or production mode

### Gateway Configuration (config.yaml)

- `model_list`: Array of agents/models to register
- `litellm_settings`: General proxy settings (verbose logging, A2A support)
- `general_settings`: UI, database, and server configuration

## Adding Agents

### Via Admin UI (Recommended)

1. Go to `http://localhost:4000/ui`
2. Navigate to "Agents" tab
3. Click "Add Agent"
4. Enter agent details:
   - Agent name
   - Invocation URL
   - Provider-specific configuration

### Via config.yaml

Add agents to the `model_list` section:

```yaml
model_list:
  - model_name: my_agent
    litellm_params:
      model: gpt-3.5-turbo
      api_base: http://localhost:8080
      custom_llm_provider: a2a
```

## Testing with A2A Python SDK

```python
from a2a import A2AClient

client = A2AClient(
    base_url="http://localhost:4000",
    api_key="sk-1234"  # Your master key
)

# List agents
agents = client.list_agents()
print(agents)
```

## Project Structure

```
agent_gateway/
├── .env                    # Environment variables (PostgreSQL connection)
├── .venv/                  # Virtual environment
├── config.yaml            # LiteLLM gateway configuration
├── requirements.txt       # Python dependencies (litellm, prisma, etc.)
├── README.md             # This file
└── docs/
    └── prompts.md        # Project roadmap and requirements
```

**Note**: Database tables are stored in PostgreSQL (`litellm` database), not in the project directory.

## Next Steps

After the gateway is operational, the following agents will be integrated from the [agentic_jarvis](https://github.com/vishalkumar9dec/agentic_jarvis) library:

1. Tickets Agent (port 8080) - IT ticket management
2. FinOps Agent (port 8081) - Cloud cost analytics
3. Oxygen Agent (port 8082) - Learning & development tracking
4. Jarvis Orchestrator - Coordinates across all agents

## Troubleshooting

### Gateway won't start

- Check if port 4000 is already in use: `lsof -i :4000`
- Verify PostgreSQL is running: `brew services list | grep postgresql`
- Ensure all dependencies are installed: `pip install -r requirements.txt`
- Check Prisma client is generated (should happen automatically on first run)

### Can't access Admin UI / "Not connected to DB" error

- Ensure PostgreSQL is running: `brew services start postgresql@15`
- Verify database exists: `/opt/homebrew/opt/postgresql@15/bin/psql -l | grep litellm`
- Check DATABASE_URL in `.env` is correct
- Try restarting the gateway

### Database connection errors

- Verify PostgreSQL service is running
- Check database credentials in DATABASE_URL
- Ensure the `litellm` database exists: `/opt/homebrew/opt/postgresql@15/bin/createdb litellm`
- Check PostgreSQL logs: `tail -f /opt/homebrew/var/log/postgresql@15.log`

### Login credentials

- Default username: `admin`
- Default password: Your `LITELLM_MASTER_KEY` from `.env` (default: `sk-1234`)

## Development

This is a development setup using PostgreSQL locally. For production:

1. Change `LITELLM_MASTER_KEY` to a secure, randomly generated value
2. Use a production PostgreSQL instance (not local Homebrew installation)
3. Enable proper authentication, SSL, and CORS policies
4. Set `ENVIRONMENT=production` in `.env`
5. Configure proper backup and monitoring for PostgreSQL

## References

- [LiteLLM A2A Documentation](https://docs.litellm.ai/docs/a2a)
- [Agentic Jarvis Repository](https://github.com/vishalkumar9dec/agentic_jarvis)
- [A2A Protocol Specification](https://a2aprotocol.org/)

## License

[Add your license here]
