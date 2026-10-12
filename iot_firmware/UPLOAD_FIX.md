# ESP32 Upload Error Fix

Error examples:

```text
A fatal error occurred: The chip stopped responding.
Failed uploading: uploading error: exit status 2
```

```text
A fatal error occurred: Serial data stream stopped: Possible serial noise or corruption.
Failed uploading: uploading error: exit status 2
```

This is **not a code compile error**. Arduino already compiled the sketch; **esptool failed while flashing** the ESP32.

If the log shows `Changing baud rate to 921600`, the upload speed is too high for your USB cable/port. Set **Upload Speed to 115200** before uploading again.

## Quick Fix (Try in this order)

### 1. Set Upload Speed to 115200 (most important)

Arduino IDE: **Tools → Upload Speed → 115200**

Do **not** use 921600 or 460800 unless you know your cable and board support it reliably.

### 2. Disconnect PZEM during upload

PZEM uses **GPIO 16 (RX)** and **GPIO 17 (TX)**. Connected PZEM can block flashing.

1. Remove PZEM TX/RX wires from ESP32 (or unplug PZEM module)
2. Upload again
3. After success, reconnect PZEM

### 3. Manual boot mode

1. Close **Serial Monitor**
2. Confirm **Tools → Upload Speed → 115200**
3. Hold **BOOT** button on ESP32
4. Click **Upload**
5. When you see `Connecting....`, release **BOOT**

### 4. Arduino IDE settings

| Setting | Value |
|---|---|
| Board | ESP32 Dev Module (or your exact board) |
| Upload Speed | **115200** |
| Flash Mode | DIO |
| Flash Size | 4MB |
| Partition Scheme | Default 4MB with spiffs |
| Erase All Flash Before Sketch Upload | **Enabled** (try once) |

### 5. USB / PC checks

- Use a **data USB cable** (not charge-only)
- Try another USB port (prefer direct laptop port, not hub)
- Close apps using COM port (Serial Monitor, PuTTY, VS Code serial)
- Reinstall USB driver: **CP210x** or **CH340** (depends on your ESP32 board)

### 6. Wiring check during upload

Keep connected:

- USB power
- OLED (I2C 21/22) — OK

Temporarily disconnect:

- PZEM on GPIO 16/17
- Relay signal wire on GPIO 26 (if upload still fails)

## After successful upload

1. Reconnect PZEM to GPIO 16/17
2. Open Serial Monitor at **115200**
3. You should see `WiFi connected` and `System Ready`

## Required libraries

Install in Arduino Library Manager:

- PZEM004Tv30
- Adafruit GFX Library
- Adafruit SSD1306
- ArduinoJson (v6+)

Board package:

- **esp32 by Espressif Systems** (Board Manager)

## Sketch folder rule

Arduino requires:

```text
correct/
  correct.ino
```

Folder name and `.ino` name must match.
