"""
Simple Test Agent for A2A Protocol
Port: 8090
"""
import os
from google.adk.agents import LlmAgent
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from a2a.types import AgentCard

# Simple tool function
def greet_user(name: str) -> str:
    """Greet a user by name.

    Args:
        name: The name of the user to greet

    Returns:
        A friendly greeting message
    """
    return f"Hello {name}! I'm the Test Agent, nice to meet you!"

def get_status() -> dict:
    """Get the current status of the agent.

    Returns:
        Status information about the agent
    """
    return {
        "status": "healthy",
        "agent": "TestAgent",
        "version": "1.0.0",
        "message": "All systems operational"
    }

# Create the agent
test_agent = LlmAgent(
    model="gemini-2.0-flash-exp",
    name="TestAgent",
    description="""I am a simple test agent for validating A2A protocol integration.

I can:
- Greet users by name
- Report my operational status

I'm here to help verify that the A2A protocol and LiteLLM gateway integration works correctly.
""",
    tools=[greet_user, get_status]
)

# Get the public URL from environment or use default
PUBLIC_URL = os.getenv("HOST_OVERRIDE", "http://test-agent:8090")

# Build custom agent card with correct URL
custom_agent_card = AgentCard(
    protocolVersion="1.0",
    name="TestAgent",
    description="Simple test agent for validating A2A protocol integration",
    url=PUBLIC_URL,
    version="1.0.0",
    defaultInputModes=["text/plain"],
    defaultOutputModes=["text/plain"],
    capabilities={},
    skills=[
        {
            "id": "greet_user",
            "name": "Greet User",
            "description": "Greets users by name",
            "tags": ["greeting"]
        },
        {
            "id": "get_status",
            "name": "Get Status",
            "description": "Reports agent operational status",
            "tags": ["health", "status"]
        }
    ]
)

# Expose via A2A protocol with custom agent card
a2a_app = to_a2a(
    test_agent,
    port=8090,
    host="0.0.0.0",
    agent_card=custom_agent_card
)

if __name__ == "__main__":
    print("=" * 80)
    print("✅ Test Agent Service Started (A2A Protocol)")
    print("=" * 80)
    print(f"Port:        8090")
    print(f"Agent Card:  http://localhost:8090/.well-known/agent-card.json")
    print("")
    print("⚠️  Note: This is an A2A agent")
    print("   - Communication happens via A2A Protocol (JSON-RPC)")
    print("   - Access via LiteLLM Gateway")
    print("=" * 80)
    print("")
    print("Service is ready to handle A2A protocol requests")
    print("Press Ctrl+C to stop")
    print("")
