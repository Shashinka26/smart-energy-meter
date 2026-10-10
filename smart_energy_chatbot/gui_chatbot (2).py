
import os
import tkinter as tk
from tkinter import scrolledtext
from datetime import datetime
from groq import Groq


# ============================================================
# GROQ API KEY - SECURE ENVIRONMENT VARIABLE
# ============================================================

api_key = os.getenv("GROQ_API_KEY")

if not api_key:
    raise ValueError(
        "GROQ_API_KEY is not set. "
        "Set the environment variable before running the chatbot."
    )

client = Groq(api_key=api_key)


# ============================================================
# SYSTEM PROMPT
# ============================================================

SYSTEM_PROMPT = """
You are a smart electricity and energy assistant for Sri Lankan households.

You help users with:
- Predicting and understanding electricity bills in Sri Lankan Rupees (Rs.)
- Energy saving tips and advice
- Best times to use appliances
- Peak vs off-peak electricity usage
- Weekly energy schedules
- Leak current warnings and electrical safety
- Understanding kWh usage

Rules:
- Always reply in the same language the user uses (Sinhala or English)
- Keep replies short and friendly (2-4 lines maximum)
- Use emojis to make replies friendly
- If the user asks something unrelated to energy/electricity,
  politely say you only assist with energy topics
- Tariff is HIGH from 6AM-6PM and LOW from 6PM-6AM in Sri Lanka
- Use Sri Lankan Rupees (Rs.) for all money amounts
"""


# ============================================================
# CONVERSATION HISTORY
# ============================================================

conversation_history = []


# ============================================================
# CHATBOT FUNCTION
# ============================================================

def chatbot(user_input):
    conversation_history.append({
        "role": "user",
        "content": user_input
    })

    try:
        response = client.chat.completions.create(
            model="openai/gpt-oss-120b",
            messages=[
                {
                    "role": "system",
                    "content": SYSTEM_PROMPT
                }
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
        # Remove the failed user message from history
        if conversation_history and conversation_history[-1] == {
            "role": "user",
            "content": user_input
        }:
            conversation_history.pop()

        return f"⚠ Error: {str(e)}"


# ============================================================
# SEND MESSAGE
# ============================================================

def send_message(event=None):
    user_input = entry.get().strip()

    if not user_input:
        return

    message_time = datetime.now().strftime("%H:%M")

    chat_area.config(state=tk.NORMAL)

    chat_area.insert(
        tk.END,
        f"You ({message_time}): {user_input}\n",
        "user"
    )

    chat_area.insert(
        tk.END,
        "Bot: Typing...\n",
        "typing"
    )

    chat_area.yview(tk.END)
    chat_area.config(state=tk.DISABLED)

    entry.delete(0, tk.END)
    send_button.config(state=tk.DISABLED)

    root.after(
        100,
        lambda: get_ai_response(user_input, message_time)
    )


# ============================================================
# GET AI RESPONSE
# ============================================================

def get_ai_response(user_input, message_time):
    try:
        response = chatbot(user_input)

        chat_area.config(state=tk.NORMAL)

        # Remove the temporary typing message
        chat_area.delete("end-2l", "end-1l")

        chat_area.insert(
            tk.END,
            f"Bot ({message_time}): {response}\n\n",
            "bot"
        )

        chat_area.yview(tk.END)
        chat_area.config(state=tk.DISABLED)

    except Exception as e:
        chat_area.config(state=tk.NORMAL)
        chat_area.insert(
            tk.END,
            f"Bot: ⚠ Error: {str(e)}\n\n",
            "bot"
        )
        chat_area.config(state=tk.DISABLED)

    finally:
        send_button.config(state=tk.NORMAL)
        entry.focus()


# ============================================================
# MAIN WINDOW
# ============================================================

root = tk.Tk()

root.title("Smart Energy Chatbot - AI Powered")
root.geometry("480x600")
root.minsize(380, 450)
root.configure(bg="#ECE5DD")


# ============================================================
# HEADER
# ============================================================

header = tk.Label(
    root,
    text="⚡ Smart Energy Assistant (AI)",
    bg="#075E54",
    fg="white",
    font=("Arial", 14, "bold"),
    pady=10
)

header.pack(fill=tk.X)


# ============================================================
# CHAT AREA
# ============================================================

chat_area = scrolledtext.ScrolledText(
    root,
    wrap=tk.WORD,
    font=("Arial", 11),
    bg="#ECE5DD",
    fg="black",
    padx=10,
    pady=10,
    state=tk.DISABLED
)

chat_area.pack(
    fill=tk.BOTH,
    expand=True
)


# ============================================================
# TEXT TAGS
# ============================================================

chat_area.tag_config(
    "user",
    foreground="#075E54",
    justify="right"
)

chat_area.tag_config(
    "bot",
    foreground="#000000",
    justify="left"
)

chat_area.tag_config(
    "typing",
    foreground="#999999",
    justify="left"
)


# ============================================================
# WELCOME MESSAGE
# ============================================================

chat_area.config(state=tk.NORMAL)

chat_area.insert(
    tk.END,
    "Bot: 👋 Hi! I'm your AI-powered Smart Energy Assistant.\n"
    "Ask me about your electricity bill, energy-saving tips,\n"
    "best times to use appliances, and more! ⚡\n\n",
    "bot"
)

chat_area.config(state=tk.DISABLED)


# ============================================================
# INPUT FRAME
# ============================================================

frame = tk.Frame(
    root,
    bg="#ECE5DD"
)

frame.pack(
    fill=tk.X,
    padx=10,
    pady=8
)


# ============================================================
# INPUT BOX
# ============================================================

entry = tk.Entry(
    frame,
    font=("Arial", 12),
    bg="white"
)

entry.pack(
    side=tk.LEFT,
    fill=tk.X,
    expand=True,
    padx=(0, 10)
)

entry.bind("<Return>", send_message)
entry.focus()


# ============================================================
# SEND BUTTON
# ============================================================

send_button = tk.Button(
    frame,
    text="Send",
    command=send_message,
    bg="#25D366",
    fg="white",
    font=("Arial", 11, "bold"),
    padx=15
)

send_button.pack(side=tk.RIGHT)


# ============================================================
# START APPLICATION
# ============================================================

root.mainloop()
