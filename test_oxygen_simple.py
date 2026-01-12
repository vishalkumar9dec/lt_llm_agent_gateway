#!/usr/bin/env python3
"""
Simple test script to invoke OxygenAgent via LiteLLM gateway
using the direct A2A endpoint format
"""
import httpx
import asyncio
from pprint import pprint

LITELLM_BASE_URL = "http://localhost:4000"
LITELLM_VIRTUAL_KEY = "sk-1234"

async def test_oxygen_agent():
    headers = {
        "Authorization": f"Bearer {LITELLM_VIRTUAL_KEY}",
        "Content-Type": "application/json"
    }

    # Use the direct A2A endpoint format
    url = f"{LITELLM_BASE_URL}/a2a/oxygen_agent/message/send"

    payload = {
        "jsonrpc": "2.0",
        "id": "test-123",
        "method": "message/send",
        "params": {
            "message": {
                "role": "user",
                "parts": [{"kind": "text", "text": "Show courses for vishal"}],
                "messageId": "msg-123"
            }
        }
    }

    print(f"Testing OxygenAgent at: {url}\n")

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
            print(f"Status: {response.status_code}\n")

            if response.status_code == 200:
                result = response.json()
                print("✅ SUCCESS!")
                pprint(result, indent=2, width=100)
            else:
                print(f"❌ ERROR: {response.status_code}")
                print(response.text)

        except Exception as e:
            print(f"❌ EXCEPTION: {e}")

if __name__ == "__main__":
    asyncio.run(test_oxygen_agent())
