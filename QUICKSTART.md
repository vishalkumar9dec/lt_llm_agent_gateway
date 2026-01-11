# LiteLLM Agent Gateway - Quick Start Guide

## Fixed: Database Connection Error

The "Authentication Error, Not connected to DB!" issue has been **resolved** by setting up PostgreSQL.

## What Was Done

1. ✅ Installed PostgreSQL 15 via Homebrew
2. ✅ Created `litellm` database
3. ✅ Updated configuration to use PostgreSQL
4. ✅ Applied all database migrations (64 migrations)
5. ✅ Gateway is now running with full database support

## Quick Start

### Option 1: Use the Startup Script (Recommended)

```bash
./start_gateway.sh
```

This script will:
- Check PostgreSQL status and start if needed
- Verify the database exists
- Start the LiteLLM gateway

### Option 2: Manual Start

```bash
# Ensure PostgreSQL is running
brew services start postgresql@15

# Activate virtual environment
source .venv/bin/activate

# Start gateway
litellm --config config.yaml
```

## Access the Admin UI

1. **Open your browser**: http://localhost:4000/ui
2. **Login with**:
   - Username: `admin`
   - Password: `sk-1234` (your LITELLM_MASTER_KEY)

## Adding Your First Agent

### Via Admin UI (Easy)

1. Go to http://localhost:4000/ui
2. Click on "Agents" or "Models" tab
3. Click "Add New Agent"
4. Fill in:
   - **Agent Name**: e.g., `my-test-agent`
   - **Model**: The backend model or service
   - **API Base** (if using A2A): http://localhost:8080 (or your agent's URL)
   - **Provider**: Select `a2a` for A2A protocol agents

### Via config.yaml (Advanced)

Edit `config.yaml` and add to `model_list`:

```yaml
model_list:
  - model_name: tickets_agent
    litellm_params:
      model: openai/gpt-4
      api_base: http://localhost:8080
      custom_llm_provider: a2a
```

## API Usage

### Health Check

```bash
curl -H "Authorization: Bearer sk-1234" http://localhost:4000/health
```

### List Agents

```bash
curl -H "Authorization: Bearer sk-1234" http://localhost:4000/v1/agents
```

## Common Commands

### Check PostgreSQL Status
```bash
brew services list | grep postgresql
```

### Stop Gateway
Press `Ctrl+C` in the terminal where it's running

### Stop PostgreSQL
```bash
brew services stop postgresql@15
```

### Restart Everything
```bash
brew services restart postgresql@15
./start_gateway.sh
```

## Next Steps

Ready to integrate your agents from [agentic_jarvis](https://github.com/vishalkumar9dec/agentic_jarvis):

1. **Tickets Agent** (port 8080) - IT ticket management
2. **FinOps Agent** (port 8081) - Cloud cost analytics
3. **Oxygen Agent** (port 8082) - Learning & development
4. **Jarvis Orchestrator** - Coordinates all agents

## Troubleshooting

**Can't login?**
- Username is always: `admin`
- Password is your `LITELLM_MASTER_KEY` from `.env` file

**Database errors?**
- Run: `brew services restart postgresql@15`
- Check: `/opt/homebrew/opt/postgresql@15/bin/psql -l | grep litellm`

**Port already in use?**
- Check what's using port 4000: `lsof -i :4000`
- Kill the process or change port in `config.yaml`

## File Locations

- **Config**: `config.yaml`
- **Environment**: `.env`
- **Logs**: Terminal output (or redirect to file)
- **Database**: PostgreSQL (`litellm` database)
- **Startup Script**: `start_gateway.sh`

---

**Gateway is running!** 🎉
Admin UI: http://localhost:4000/ui
