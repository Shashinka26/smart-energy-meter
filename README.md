# Smart Energy Meter

Final year IoT project for live electricity monitoring, **ML bill prediction**, smart scheduling, and mobile control. Built with **Flutter**, **Firebase Realtime Database**, **ESP32**, and **Python ML backend**.

## Project Structure

```
smart_energy_app/          Flutter mobile app
ml_backend/                Python ML training + Flask API
iot_firmware/              ESP32 + PZEM + Relay firmware
assets/ml_model.json       Exported Linear Regression coefficients
```

## Features

- Live monitoring: voltage, current, power, energy, frequency, power factor
- ML bill prediction from live sensor readings
- Rule-based schedule model with peak/off-peak tariff advice
- Auto/manual relay control through Firebase
- Dashboard, Analytics, Schedule, Profile screens
- Firebase Realtime Database as the cloud layer

## Technology Stack

| Layer | Tools |
|-------|-------|
| Mobile | Flutter, Dart |
| Cloud | Firebase Realtime Database |
| IoT | ESP32, PZEM-004T, Relay |
| ML | Python, scikit-learn, Flask |

## Flutter App Setup

```bash
flutter pub get
flutter run
```

Release APK:

```bash
flutter build apk --release
```

## ML Backend Setup

```bash
cd ml_backend
pip install -r requirements.txt
python train_model.py
python backend.py
```

Training generates:

- `ml_backend/bill_model.pkl`
- `assets/ml_model.json` for on-device prediction in the app

Optional backend URL for the app:

```bash
flutter run --dart-define=ML_BACKEND_URL=http://192.168.x.x:5000
```

## ESP32 Firmware

1. Open `iot_firmware/correct.ino` in Arduino IDE
2. Install libraries: PZEM004Tv30, Adafruit SSD1306, ArduinoJson
3. Update WiFi credentials
4. Upload to ESP32

## Firebase Nodes

```
SmartMeter/      live readings + relay + scheduleMode
Schedules/       user automation rules
UsageHistory/    historical power samples for schedule analysis
```

## Architecture

```
ESP32 + PZEM + Relay
        │
        ▼
Firebase Realtime Database
        │
        ├── Flutter App (Dashboard, Analytics, Schedule, Profile)
        └── ML Backend (optional Flask API)
```

## Demo Flow

1. Power ESP32 and confirm Firebase live data
2. Open Dashboard for real-time readings
3. Open Analytics for ML bill prediction
4. Create schedule and enable Auto mode
5. Show Profile and system overview

## Author

**Chamidu Shashinka Rathnasiri**

- GitHub: https://github.com/Shashinka26
- LinkedIn: https://www.linkedin.com/in/chamidu-shashinka-947709361

Repository: https://github.com/Shashinka26/smart-energy-meter.git
