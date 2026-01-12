#!/usr/bin/env python3
"""
Interactive Test Script for Test Agent
Run this to manually test the agent and understand how it works
"""
import httpx
import asyncio
from uuid import uuid4
from pprint import pprint

GATEWAY_URL = "http://localhost:4000"
API_KEY = "sk-1234"
AGENT_NAME = "test_agent"

async def invoke_agent(message: str, show_details: bool = True):
    """Send a message to the test agent and display results"""
    url = f"{GATEWAY_URL}/a2a/{AGENT_NAME}/message/send"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "jsonrpc": "2.0",
        "id": str(uuid4()),
        "method": "message/send",
        "params": {
            "message": {
                "role": "user",
                "parts": [{"kind": "text", "text": message}],
                "messageId": str(uuid4())
            }
        }
    }

    print(f"\n{'='*70}")
    print(f"📤 Sending to agent: {message}")
    print(f"{'='*70}")

    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
            result = response.json()

            if "result" in result:
                # Extract the answer
                answer = result["result"]["artifacts"][0]["parts"][0]["text"]
                print(f"\n✅ Agent Response:")
                print(f"{answer}")

                if show_details:
                    # Show token usage
                    metadata = result["result"]["metadata"]
                    tokens = metadata.get("adk_usage_metadata", {}).get("totalTokenCount", 0)
                    print(f"\n📊 Token Usage: {tokens} tokens")

                    # Show tool calls
                    history = result["result"]["history"]
                    tool_calls = []
                    tool_responses = []

                    for h in history:
                        parts = h.get("parts", [])
                        if parts:
                            part = parts[0]
                            adk_type = part.get("metadata", {}).get("adk_type")

                            if adk_type == "function_call":
                                tool_calls.append(part["data"])
                            elif adk_type == "function_response":
                                tool_responses.append(part["data"])

                    if tool_calls:
                        print(f"\n🔧 Tools Called:")
                        for i, tool in enumerate(tool_calls):
                            print(f"   [{i+1}] {tool['name']}()")
                            print(f"       Args: {tool.get('args', {})}")
                            if i < len(tool_responses):
                                resp = tool_responses[i].get('response', {})
                                print(f"       Result: {resp}")

                    # Show conversation flow
                    print(f"\n💬 Conversation Flow:")
                    for i, h in enumerate(history):
                        role = h.get("role", "unknown")
                        parts = h.get("parts", [])
                        if parts:
                            part_kind = parts[0].get("kind", "unknown")
                            if part_kind == "text":
                                text = parts[0].get("text", "")
                                print(f"   [{i+1}] {role}: {text[:80]}...")
                            elif part_kind == "data":
                                adk_type = parts[0].get("metadata", {}).get("adk_type", "data")
                                print(f"   [{i+1}] {role}: [{adk_type}]")

                    # Show status
                    status = result["result"]["status"]
                    print(f"\n📌 Status: {status['state']}")

            else:
                print(f"\n❌ Error: {result.get('error', result)}")

        except Exception as e:
            print(f"\n❌ Exception: {e}")

async def test_suite():
    """Run a suite of tests"""
    print("\n" + "="*70)
    print("🧪 TEST AGENT - INTERACTIVE TEST SUITE")
    print("="*70)

    # Test 1: Greet with name
    print("\n\n[TEST 1] Testing greet_user tool")
    print("-" * 70)
    await invoke_agent("Hi! Can you greet me? My name is Vishal.")

    input("\n\nPress Enter to continue to next test...")

    # Test 2: Status check
    print("\n\n[TEST 2] Testing get_status tool")
    print("-" * 70)
    await invoke_agent("What is your operational status?")

    input("\n\nPress Enter to continue to next test...")

    # Test 3: General question
    print("\n\n[TEST 3] Testing general response (no tool)")
    print("-" * 70)
    await invoke_agent("What can you help me with?")

    input("\n\nPress Enter to continue to next test...")

    # Test 4: Multiple tool usage
    print("\n\n[TEST 4] Testing multiple interactions")
    print("-" * 70)
    await invoke_agent("First check your status, then greet me as Alex.")

    input("\n\nPress Enter to continue to next test...")

    # Test 5: Edge case
    print("\n\n[TEST 5] Testing with different name")
    print("-" * 70)
    await invoke_agent("Greet someone named Happy!")

    print("\n\n" + "="*70)
    print("✅ All tests completed!")
    print("="*70)

async def interactive_mode():
    """Interactive mode - ask your own questions"""
    print("\n" + "="*70)
    print("💬 INTERACTIVE MODE")
    print("="*70)
    print("Type your messages to the agent. Type 'quit' or 'exit' to stop.")
    print("Type 'simple' to toggle simple output mode.")
    print("-" * 70)

    show_details = True

    while True:
        try:
            user_input = input("\n\nYou: ").strip()

            if not user_input:
                continue

            if user_input.lower() in ['quit', 'exit', 'q']:
                print("\n👋 Goodbye!")
                break

            if user_input.lower() == 'simple':
                show_details = not show_details
                print(f"{'Detailed' if show_details else 'Simple'} mode enabled")
                continue

            await invoke_agent(user_input, show_details=show_details)

        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"\n❌ Error: {e}")

async def main():
    """Main entry point"""
    print("\n")
    print("╔" + "═"*68 + "╗")
    print("║" + " "*68 + "║")
    print("║" + "  🤖  TEST AGENT - MANUAL TESTING SCRIPT  🤖".center(68) + "║")
    print("║" + " "*68 + "║")
    print("╚" + "═"*68 + "╝")

    print("\nWhat would you like to do?")
    print("  1. Run automated test suite")
    print("  2. Interactive mode (ask your own questions)")
    print("  3. Quick test (single greeting)")
    print("  4. Exit")

    choice = input("\nEnter choice (1-4): ").strip()

    if choice == "1":
        await test_suite()
    elif choice == "2":
        await interactive_mode()
    elif choice == "3":
        await invoke_agent("Hello! Can you greet me? My name is Vishal.")
    elif choice == "4":
        print("\n👋 Goodbye!")
    else:
        print("\n❌ Invalid choice")

if __name__ == "__main__":
    asyncio.run(main())
