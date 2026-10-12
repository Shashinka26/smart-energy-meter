# Gemini AI Setup (Required Once)

## 1. Upgrade Firebase plan
- Firebase Console → **Upgrade** → **Blaze (pay-as-you-go)**
- Spark plan blocks Gemini API calls

## 2. Enable AI Logic
- Firebase Console → **Build → AI Logic → Settings**
- Enable Gemini / Google AI

## 3. Enable Google Cloud API
- [Google Cloud Console](https://console.cloud.google.com) → project `smart-energy-meter-266d8`
- **APIs & Services → Library → Generative Language API → Enable**

## 4. Register App Check debug token (release APK)
- Open app → **Energy AI** screen
- If not connected, copy the **App Check token** shown in the orange status bar
- Firebase Console → **App Check → Apps → smart_energy_app (android) → Manage debug tokens**
- Paste token → Save
- Restart app

## 5. Test
- Energy AI → send: `How can I save energy?`
