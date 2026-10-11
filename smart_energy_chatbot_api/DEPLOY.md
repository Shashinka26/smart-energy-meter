# Deploy Smart Energy Chatbot API (Render)

## One-time setup (~5 minutes)

1. Push this folder to GitHub (or use the repo created by Cursor).
2. Go to [render.com](https://render.com) → **New** → **Blueprint** (or **Web Service**).
3. Connect the repo and select `smart_energy_chatbot_api`.
4. Add environment variable:
   - `GROQ_API_KEY` = your Groq API key
5. Deploy. Your URL will be:
   - `https://smart-energy-chatbot-api.onrender.com`

## Test

- Health: `https://smart-energy-chatbot-api.onrender.com/health`
- Chat: POST JSON `{"message": "How can I save electricity?"}` to `/chat`

## Notes

- Free tier sleeps after ~15 min idle; first request may take ~30 seconds.
- No PC or local Python command needed after deploy.
