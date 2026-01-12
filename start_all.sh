#!/bin/bash
# Start LiteLLM Agent Gateway with PostgreSQL

set -e

echo "=========================================="
echo "  LiteLLM Agent Gateway - Startup"
echo "=========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found!${NC}"
    echo "Please create .env file with required variables:"
    echo "  - LITELLM_MASTER_KEY"
    echo "  - POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB"
    exit 1
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running!${NC}"
    echo "Please start Docker Desktop and try again."
    exit 1
fi

echo -e "${GREEN}✓${NC} .env file found"
echo -e "${GREEN}✓${NC} Docker is running"
echo ""

# Stop any existing containers
echo "Stopping existing containers (if any)..."
docker-compose down 2>/dev/null || true
echo ""

# Start services
echo "Starting gateway services..."
echo ""

docker-compose up -d

# Wait for services to be healthy
echo ""
echo "Waiting for services to become healthy..."
echo "(This may take 30-40 seconds)"
echo ""

sleep 15

# Check service status
echo "Service Status:"
echo "=========================================="
docker-compose ps
echo ""

# Display service information
echo "=========================================="
echo "  Gateway Ready!"
echo "=========================================="
echo ""
echo -e "${GREEN}PostgreSQL:${NC}"
echo "  - Port: 5432"
echo "  - Database: litellm"
echo ""
echo -e "${GREEN}LiteLLM Gateway:${NC}"
echo "  - URL: http://localhost:4000"
echo "  - Admin UI: http://localhost:4000/ui"
echo "  - Health: http://localhost:4000/health"
echo "  - API Key: sk-1234"
echo ""
echo "=========================================="
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Add A2A Agents via Admin UI:"
echo "   - Open: http://localhost:4000/ui"
echo "   - Navigate to 'Agents' tab"
echo "   - Click 'Add Agent'"
echo "   - Enter agent name and URL"
echo ""
echo "2. For local agents running on host machine:"
echo "   - Use: http://host.docker.internal:PORT"
echo "   - Example: http://host.docker.internal:8080"
echo ""
echo "3. View logs:"
echo "   docker-compose logs -f"
echo ""
echo "4. Stop gateway:"
echo "   docker-compose down"
echo ""
echo "=========================================="
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo "  - Architecture: docs/AGENT_ARCHITECTURE.md"
echo "  - See 'agentic_jarvis' project for running agents"
echo ""
