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

## Behavior

- Uploads live readings to `SmartMeter/`
- Saves usage history every 5 minutes
- Reads `Schedules/` and controls relay in auto mode
- Respects manual relay commands in manual mode
