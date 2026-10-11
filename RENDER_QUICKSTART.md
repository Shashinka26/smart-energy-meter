# URGENT: Deploy chatbot to Render (2 minutes)

Your code is already on GitHub: `Shashinka26/smart-energy-meter`

## Steps

1. Open: https://dashboard.render.com/blueprints
2. Click **New Blueprint Instance**
3. Connect GitHub → select **smart-energy-meter** repo
4. Render detects `render.yaml` automatically
5. When asked for **GROQ_API_KEY**, paste your Groq API key
6. Click **Apply** / **Deploy**
7. Wait ~3 minutes until status is **Live**
8. Test in browser: https://smart-energy-chatbot-api.onrender.com/health

## After deploy

- Install the new APK: `build/app/outputs/flutter-apk/app-release.apk`
- Open app → Energy AI → send a message
- **No PC, no Python command needed**
- First request after idle may take ~30 seconds (free tier wake-up)

## If service name differs

If Render gives a different URL, rebuild APK:

```powershell
flutter build apk --dart-define=CHATBOT_API_URL=https://YOUR-URL.onrender.com
```
