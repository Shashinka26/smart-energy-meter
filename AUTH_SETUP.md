# Owner-Only Relay Control Setup

## 1. Enable Firebase Authentication

1. Open [Firebase Console](https://console.firebase.google.com/) → **smart-energy-meter-266d8**
2. Go to **Build → Authentication → Sign-in method**
3. Enable **Email/Password**

## 2. Deploy Database Rules

1. Go to **Build → Realtime Database → Rules**
2. Copy the contents of `database.rules.json` from this folder
3. Paste and **Publish**

## 3. Register Accounts

### First account (Owner)
1. Open the app → **Register**
2. Enter email + password (6+ characters)
3. Tap **Create Account**
4. This account becomes the **owner** with full relay control

No setup code is required.

### Additional accounts (Viewer)
1. Anyone else who registers gets a **viewer** account
2. They can monitor usage but **cannot control the relay**

## 4. ESP32 Firmware

Re-upload `iot_firmware/correct.ino` if not done already. Manual mode reads `SmartMeter/relayCommand`.

## Reset Owner

To change owner, delete `Config/ownerUid` in Firebase Realtime Database and remove old users from **Authentication → Users**, then register again on the new account.
