# ESP32 Smart Meter Firmware

Hardware:

- ESP32
- PZEM-004T
- Relay module on GPIO 26
- OLED SSD1306

## Required Arduino Libraries

- PZEM004Tv30
- Adafruit GFX
- Adafruit SSD1306
- ArduinoJson

## Configuration

Update in `correct.ino`:

- `WIFI_SSID`
- `WIFI_PASSWORD`
- `DATABASE_URL`

## Upload (Arduino IDE)

Before uploading:

1. **Tools → Upload Speed → 115200** (do not use 921600)
2. Disconnect **PZEM TX/RX** from GPIO 16/17 during upload
3. Close Serial Monitor, then click Upload
4. If needed: hold **BOOT** while uploading until `Connecting....` appears

If upload fails, see [UPLOAD_FIX.md](UPLOAD_FIX.md).

## Behavior

- Uploads live readings to `SmartMeter/`
- Saves usage history every 5 minutes
- Reads `Schedules/` and controls relay in auto mode
- Respects manual relay commands via `SmartMeter/relayCommand` in manual mode
