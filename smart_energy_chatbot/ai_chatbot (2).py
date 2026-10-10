
import os
from groq import Groq

api_key = os.getenv("GROQ_API_KEY")

if not api_key:
    raise RuntimeError(
        "GROQ_API_KEY is missing. Set it in your terminal."
    )

client = Groq(api_key=api_key)

SYSTEM_PROMPT = """
You are a smart electricity and energy assistant for Sri Lankan households.
You help users with:
- Predicting and understanding electricity bills in Sri Lankan Rupees (Rs.)
- Energy saving tips and advice
- Best times to use appliances (peak vs off-peak hours)
- Weekly energy schedules
- Electrical safety and leakage-current warnings
- Understanding kWh usage

Rules:
- Always reply in the same language the user uses (Sinhala or English).
- Keep replies short and friendly (2-4 lines maximum).
- Use emojis to make replies friendly.
- If the question is unrelated to energy or electricity, politely explain
  that you only assist with energy topics.
- Use Sri Lankan Rupees (Rs.) for money amounts.
- Do not claim that tariff rates are current unless verified.
"""

conversation_history = []


def chatbot(user_input):
    conversation_history.append({
        "role": "user",
        "content": user_input
    })

    try:
        response = client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT}
            ] + conversation_history,
            max_tokens=200,
            temperature=0.7
        )

        reply = response.choices[0].message.content.strip()

        conversation_history.append({
            "role": "assistant",
            "content": reply
        })

        return reply

    except Exception as e:
        conversation_history.pop()
        return f"⚠ Error: {e}"


def main():
    print("⚡ Smart Energy AI Chatbot Ready!")
    print("💡 Ask me about electricity and energy saving.")
    print("Type 'exit' to quit.\n")

    while True:
        user = input("You: ").strip()

        if user.lower() == "exit":
            print("Bot: Goodbye! Save energy! 👋⚡")
            break

        if not user:
            continue

        print("Bot:", chatbot(user))
        print()


if __name__ == "__main__":
    main()
