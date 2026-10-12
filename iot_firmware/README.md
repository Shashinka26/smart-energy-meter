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
- WiFiManager (by tzapu) — install via **Sketch → Include Library → Manage Libraries**

## Configuration

Update in `correct.ino`:

- `DATABASE_URL`

WiFi credentials are **not** hard-coded. On first boot (or after reset), the ESP32 creates a hotspot named **`SmartEnergy_Setup`**. Connect with your phone, open the captive portal (or go to `http://192.168.4.1`), enter your WiFi SSID and password, and save. Credentials are stored in flash and reused on restart.

To change WiFi later: **hold the BOOT button (GPIO 0) for 3 seconds while powering on** — settings are cleared and setup starts again.

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
