#!/bin/bash
# LiteLLM Agent Gateway Startup Script

set -e

echo "🚀 Starting LiteLLM Agent Gateway..."

# Check if PostgreSQL is running
if ! brew services list | grep -q "postgresql@15.*started"; then
    echo "⚠️  PostgreSQL is not running. Starting PostgreSQL..."
    brew services start postgresql@15
    sleep 2
fi

# Check if database exists
if ! /opt/homebrew/opt/postgresql@15/bin/psql -lqt | cut -d \| -f 1 | grep -qw litellm; then
    echo "📊 Creating litellm database..."
    /opt/homebrew/opt/postgresql@15/bin/createdb litellm
fi

# Activate virtual environment
source .venv/bin/activate

# Start the gateway
echo "✅ PostgreSQL is running"
echo "✅ Database is ready"
echo "🌐 Starting gateway on http://localhost:4000"
echo "🔑 Admin UI: http://localhost:4000/ui"
echo "🔐 Username: admin | Password: sk-1234"
echo ""

litellm --config config.yaml
