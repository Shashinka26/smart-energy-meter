#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <PZEM004Tv30.h>
#include <ArduinoJson.h>
#include <time.h>

#define WIFI_SSID "Pixel_5082"
#define WIFI_PASSWORD "12332112"

#define DATABASE_URL "https://smart-energy-meter-266d8-default-rtdb.asia-southeast1.firebasedatabase.app"

#define RELAY_PIN 26
#define RELAY_ON HIGH
#define RELAY_OFF LOW

#define PZEM_RX 16
#define PZEM_TX 17

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800;
const int daylightOffset_sec = 0;

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);
PZEM004Tv30 pzem(Serial2, PZEM_RX, PZEM_TX);
WiFiClientSecure client;

unsigned long lastUpload = 0;
unsigned long lastWiFiTry = 0;
unsigned long lastScheduleCheck = 0;
unsigned long lastHistoryUpload = 0;

bool relayState = true;
String scheduleMode = "manual";
bool timeSynced = false;

void oled(String a, String b = "", String c = "") {
  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.println(a);
  if (b != "") display.println(b);
  if (c != "") display.println(c);
  display.display();
}

void connectWiFiNonBlock() {
  if (WiFi.status() == WL_CONNECTED) return;

  if (millis() - lastWiFiTry < 10000) return;
  lastWiFiTry = millis();

  Serial.println("WiFi connecting...");
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void setupTime() {
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);

  struct tm timeinfo;
  for (int i = 0; i < 20; i++) {
    if (getLocalTime(&timeinfo)) {
      timeSynced = true;
      Serial.println("NTP time synced");
      return;
    }
    delay(500);
  }

  Serial.println("NTP sync failed");
}

bool getLocalTimeInfo(struct tm &timeinfo) {
  return getLocalTime(&timeinfo);
}

String httpGet(const String &path) {
  if (WiFi.status() != WL_CONNECTED) return "";

  client.setInsecure();
  HTTPClient http;

  String url = String(DATABASE_URL) + path;
  http.begin(client, url);
  int code = http.GET();
  String payload = "";

  if (code == 200) {
    payload = http.getString();
  } else {
    Serial.print("GET failed ");
    Serial.print(path);
    Serial.print(" code: ");
    Serial.println(code);
  }

  http.end();
  return payload;
}

bool httpPutJson(const String &path, const String &json) {
  if (WiFi.status() != WL_CONNECTED) return false;

  client.setInsecure();
  HTTPClient http;

  String url = String(DATABASE_URL) + path;
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  int code = http.PUT(json);
  http.end();

  return code == 200;
}

bool parseBoolValue(const String &payload) {
  String trimmed = payload;
  trimmed.trim();
  return trimmed == "true";
}

String parseStringValue(const String &payload) {
  String trimmed = payload;
  trimmed.trim();

  if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() >= 2) {
    return trimmed.substring(1, trimmed.length() - 1);
  }

  return trimmed;
}

bool matchesRepeat(const String &repeat, int weekday) {
  if (repeat == "Every Day") return true;
  if (repeat == "Weekdays") return weekday >= 1 && weekday <= 5;
  if (repeat == "Weekends") return weekday == 0 || weekday == 6;
  if (repeat == "Once") return true;
  return false;
}

bool isTimeInRange(int hour, int minute, int startH, int startM, int endH, int endM) {
  int now = hour * 60 + minute;
  int start = startH * 60 + startM;
  int end = endH * 60 + endM;

  if (start <= end) {
    return now >= start && now < end;
  }

  return now >= start || now < end;
}

bool evaluateSchedules(bool &foundMatch) {
  foundMatch = false;

  struct tm timeinfo;
  if (!getLocalTimeInfo(timeinfo)) {
    return relayState;
  }

  String payload = httpGet("/Schedules.json");
  if (payload.length() == 0 || payload == "null") {
    return true;
  }

  DynamicJsonDocument doc(8192);
  DeserializationError error = deserializeJson(doc, payload);
  if (error) {
    Serial.println("Schedule JSON parse failed");
    return relayState;
  }

  JsonObject schedules = doc.as<JsonObject>();
  bool result = true;

  for (JsonPair kv : schedules) {
    JsonObject schedule = kv.value().as<JsonObject>();

    if (!schedule["enabled"].as<bool>()) {
      continue;
    }

    int startH = schedule["startHour"] | 0;
    int startM = schedule["startMinute"] | 0;
    int endH = schedule["endHour"] | 0;
    int endM = schedule["endMinute"] | 0;
    String repeat = schedule["repeat"] | "Every Day";
    String action = schedule["action"] | "ON";

    if (!matchesRepeat(repeat, timeinfo.tm_wday)) {
      continue;
    }

    if (!isTimeInRange(timeinfo.tm_hour, timeinfo.tm_min, startH, startM, endH, endM)) {
      continue;
    }

    foundMatch = true;
    result = action == "ON";
  }

  return result;
}

void updateRelayControl() {
  if (WiFi.status() != WL_CONNECTED) {
    return;
  }

  String modePayload = httpGet("/SmartMeter/scheduleMode.json");
  if (modePayload.length() > 0 && modePayload != "null") {
    scheduleMode = parseStringValue(modePayload);
  }

  if (scheduleMode == "auto") {
    bool foundMatch = false;
    relayState = evaluateSchedules(foundMatch);

    if (!foundMatch) {
      relayState = true;
    }
  } else {
    String relayPayload = httpGet("/SmartMeter/relay.json");
    if (relayPayload.length() > 0 && relayPayload != "null") {
      relayState = parseBoolValue(relayPayload);
    }
  }

  digitalWrite(RELAY_PIN, relayState ? RELAY_ON : RELAY_OFF);
}

bool readPZEM(float &v, float &i, float &p, float &e, float &f, float &pf) {
  for (int x = 0; x < 5; x++) {
    delay(300);

    v = pzem.voltage();

    if (!isnan(v)) {
      i = pzem.current();
      p = pzem.power();
      e = pzem.energy();
      f = pzem.frequency();
      pf = pzem.pf();
      return true;
    }

    Serial.println("PZEM retry...");
  }

  return false;
}

void uploadFirebase(float v, float i, float p, float e, float f, float pf) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Firebase skip: WiFi not connected");
    return;
  }

  String json = "{";
  json += "\"voltage\":" + String(v, 2) + ",";
  json += "\"current\":" + String(i, 3) + ",";
  json += "\"power\":" + String(p, 2) + ",";
  json += "\"energy\":" + String(e, 3) + ",";
  json += "\"frequency\":" + String(f, 2) + ",";
  json += "\"powerFactor\":" + String(pf, 2) + ",";
  json += "\"relay\":" + String(relayState ? "true" : "false") + ",";
  json += "\"scheduleMode\":\"" + scheduleMode + "\"";
  json += "}";

  bool ok = httpPutJson("/SmartMeter.json", json);

  Serial.print("Firebase upload: ");
  Serial.println(ok ? "OK" : "FAILED");
}

void uploadUsageHistory(float power, float energy) {
  struct tm timeinfo;
  if (!getLocalTimeInfo(timeinfo)) {
    return;
  }

  char dateStr[11];
  char timeStr[6];
  strftime(dateStr, sizeof(dateStr), "%Y-%m-%d", &timeinfo);
  strftime(timeStr, sizeof(timeStr), "%H-%M", &timeinfo);

  String path = "/UsageHistory/" + String(dateStr) + "/" + String(timeStr) + ".json";

  String json = "{";
  json += "\"power\":" + String(power, 2) + ",";
  json += "\"energy\":" + String(energy, 3) + ",";
  json += "\"timestamp\":" + String(millis());
  json += "}";

  httpPutJson(path, json);
  Serial.println("Usage history saved");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_ON);

  Wire.begin(21, 22);

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED Failed");
    while (1);
  }

  oled("Smart Energy", "Relay ON", "PZEM starting");
  delay(5000);

  Serial2.begin(9600, SERIAL_8N1, PZEM_RX, PZEM_TX);

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWiFi connected");
  setupTime();

  httpPutJson("/SmartMeter/scheduleMode.json", "\"manual\"");

  Serial.println("System Ready");
}

void loop() {
  connectWiFiNonBlock();

  if (WiFi.status() == WL_CONNECTED && !timeSynced) {
    setupTime();
  }

  if (millis() - lastScheduleCheck > 30000) {
    updateRelayControl();
    lastScheduleCheck = millis();
  }

  float voltage, current, power, energy, freq, pf;

  bool ok = readPZEM(voltage, current, power, energy, freq, pf);

  if (!ok) {
    Serial.println("PZEM ERROR");

    oled(
      "PZEM ERROR",
      WiFi.status() == WL_CONNECTED ? "WiFi:OK" : "WiFi:NO",
      relayState ? "Relay:ON" : "Relay:OFF"
    );

    delay(1000);
    return;
  }

  Serial.println("---------");
  Serial.print("Voltage: "); Serial.println(voltage);
  Serial.print("Current: "); Serial.println(current);
  Serial.print("Power: "); Serial.println(power);
  Serial.print("Energy: "); Serial.println(energy);
  Serial.print("Freq: "); Serial.println(freq);
  Serial.print("PF: "); Serial.println(pf);
  Serial.print("Relay: "); Serial.println(relayState ? "ON" : "OFF");
  Serial.print("Mode: "); Serial.println(scheduleMode);
  Serial.print("WiFi: "); Serial.println(WiFi.status() == WL_CONNECTED ? "OK" : "NO");

  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.println("Smart Energy");
  display.print("WiFi:");
  display.println(WiFi.status() == WL_CONNECTED ? "OK" : "NO");
  display.print("Mode:");
  display.println(scheduleMode == "auto" ? "AUTO" : "MAN");
  display.print("Relay:");
  display.println(relayState ? "ON" : "OFF");

  display.print("V:");
  display.print(voltage, 1);
  display.println("V");

  display.print("P:");
  display.print(power, 1);
  display.println("W");

  display.print("E:");
  display.print(energy, 3);
  display.println("kWh");

  display.display();

  if (millis() - lastUpload > 10000) {
    uploadFirebase(voltage, current, power, energy, freq, pf);
    lastUpload = millis();
  }

  if (millis() - lastHistoryUpload > 300000) {
    uploadUsageHistory(power, energy);
    lastHistoryUpload = millis();
  }

  delay(1000);
}
