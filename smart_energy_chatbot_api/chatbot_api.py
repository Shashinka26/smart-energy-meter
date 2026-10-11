import os

from flask import Flask, jsonify, request
from flask_cors import CORS
from groq import Groq

app = Flask(__name__)
CORS(app)

MODEL = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")

SYSTEM_PROMPT = """You are a smart electricity and energy assistant for Sri Lankan households.

Help users with:
- Understanding electricity bills in Sri Lankan Rupees (Rs.)
- Energy-saving tips
- Appliance usage and peak/off-peak electricity
- Weekly energy schedules
- Electrical safety and leakage warnings
- Understanding kWh usage

Rules:
- Reply in the same language as the user, Sinhala or English.
- Keep replies friendly and concise, usually 2-4 lines.
- Use emojis naturally.
- For unrelated questions, politely explain that you only assist with energy and electricity topics.
- Use Rs. for money amounts.
- Do not claim tariff rates are current unless verified.
- Do not invent meter readings or bill amounts.
- Make clear that bill estimates are not official bills."""

_client = None

# Prototype conversation history for a single user session on this server instance.
conversation_history = []


def get_groq_client() -> Groq:
    global _client
    if _client is not None:
        return _client

    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError(
            "GROQ_API_KEY is missing. Set it in Render environment variables."
        )

    _client = Groq(api_key=api_key)
    return _client


@app.get("/")
def root():
    return jsonify({
        "status": "ok",
        "service": "Smart Energy Chatbot API",
    })


@app.get("/health")
def health():
    return jsonify({
        "status": "ok",
        "service": "Smart Energy Chatbot API",
    })


@app.post("/chat")
def chat():
    payload = request.get_json(silent=True) or {}
    user_message = (payload.get("message") or "").strip()

    if not user_message:
        return jsonify({"error": "message is required"}), 400

    conversation_history.append({"role": "user", "content": user_message})

    try:
        client = get_groq_client()
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                *conversation_history,
            ],
        )
        reply = response.choices[0].message.content or ""
        conversation_history.append({"role": "assistant", "content": reply})
        return jsonify({"reply": reply})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5001"))
    app.run(host="0.0.0.0", port=port, debug=False)
