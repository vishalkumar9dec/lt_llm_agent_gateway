from uuid import uuid4
import httpx
import asyncio
from a2a.client import A2ACardResolver, A2AClient
from a2a.types import MessageSendParams, SendMessageRequest

# === CONFIGURE THESE ===
LITELLM_BASE_URL = "http://localhost:4000"  # Your LiteLLM proxy URL
LITELLM_VIRTUAL_KEY = "sk-1234"             # Your LiteLLM Virtual Key
# =======================

async def main():
    headers = {"Authorization": f"Bearer {LITELLM_VIRTUAL_KEY}"}
    
    async with httpx.AsyncClient(headers=headers) as client:
        # Step 1: List available agents
        response = await client.get(f"{LITELLM_BASE_URL}/v1/agents")
        agents = response.json()
        
        print("Available agents:")
        for agent in agents:
            print(f"  - {agent['agent_name']} (ID: {agent['agent_id']})")
        
        if not agents:
            print("No agents available for this key")
            return
        
        # Step 2: Select an agent and invoke it
        selected_agent = agents[0]
        agent_id = selected_agent["agent_id"]
        agent_name = selected_agent["agent_name"]
        print(f"\nInvoking: {agent_name}")
        
        # Step 3: Use A2A protocol to invoke the agent
        base_url = f"{LITELLM_BASE_URL}/a2a/{agent_id}"
        resolver = A2ACardResolver(httpx_client=client, base_url=base_url)
        agent_card = await resolver.get_agent_card()
        a2a_client = A2AClient(httpx_client=client, agent_card=agent_card)
        
        request = SendMessageRequest(
            id=str(uuid4()),
            params=MessageSendParams(
                message={
                    "role": "user",
                    "parts": [{"kind": "text", "text": "Hello, what can you do?"}],
                    "messageId": uuid4().hex,
                }
            ),
        )
        response = await a2a_client.send_message(request)
        print(f"Response: {response.model_dump(mode='json', exclude_none=True, indent=4)}")

if __name__ == "__main__":
    asyncio.run(main())