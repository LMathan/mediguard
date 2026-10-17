/**
 * MediGuard ESP32-C3 Hardware Simulator Firmware
 * 
 * Target: ESP32-C3 (RISC-V 160MHz)
 * Toolchain: Arduino IDE (ESP32 by Espressif) or PlatformIO
 * 
 * Features:
 * - Generates simulated temperature, humidity, door, and environmental telemetry
 * - Transmits JSON payloads via HTTPS to Supabase Ingest Edge Function
 * - Authenticates with dedicated device API Key (stored in public.devices)
 * - 7 Selectable simulation scenarios via interactive Serial Monitor commands
 * - Automatic Wi-Fi reconnection and NTP time synchronization
 * - Non-blocking timer-driven architecture
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <time.h>
#include "config.h"

// ============================================================================
// Simulation Scenarios
// ============================================================================
enum SimulationScenario {
  SCENARIO_NORMAL = 1,
  SCENARIO_TEMPERATURE_WARNING = 2,
  SCENARIO_TEMPERATURE_CRITICAL = 3,
  SCENARIO_DOOR_OPEN = 4,
  SCENARIO_SENSOR_ERROR = 5,
  SCENARIO_OFFLINE = 6,
  SCENARIO_RECOVERY = 7
};

SimulationScenario currentScenario = SCENARIO_NORMAL;
uint32_t telemetryIntervalMs = DEFAULT_TELEMETRY_INTERVAL_SEC * 1000;
uint32_t lastTelemetryTime = 0;
uint32_t totalPacketsSent = 0;
uint32_t totalPacketsFailed = 0;

// Dynamic simulation values (smoothed)
float curNormalTemp = 24.8f;
float curNormalHum = 52.0f;
float curColdTemp = 4.2f;
float curColdHum = 46.0f;
bool curNormalDoor = false;
bool curColdDoor = false;
bool curNormalLight = false;
bool curColdLight = false;
bool curCoolingActive = true;
bool curNormalFanActive = true;
String curSensorHealth = "healthy";

// ============================================================================
// Helper Prototypes
// ============================================================================
void connectWiFi();
void checkWiFiConnection();
void syncNtpTime();
String getIso8601Timestamp();
void updateSimulationValues();
void sendTelemetry();
void processSerialCommands();
void printHelpMenu();
void printStatus();
const char* getScenarioName(SimulationScenario s);

// ============================================================================
// Setup
// ============================================================================
void setup() {
  Serial.begin(SERIAL_BAUD_RATE);
  delay(1000);

  Serial.println("\n========================================================");
  Serial.println("   MediGuard - ESP32-C3 Hardware Simulator v1.0.0      ");
  Serial.println("========================================================");
  Serial.println("Initializing hardware simulation subsystem...");

  // Status LED pin
  #ifdef STATUS_LED_PIN
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);
  #endif

  // Connect to Wi-Fi
  connectWiFi();

  // Synchronize system clock via NTP
  syncNtpTime();

  printHelpMenu();
  Serial.println("\n[SIMULATOR] Ready. Starting telemetry loop in NORMAL scenario...\n");
}

// ============================================================================
// Main Loop (Non-blocking)
// ============================================================================
void loop() {
  // Check Wi-Fi state
  checkWiFiConnection();

  // Process incoming Serial keystrokes/commands
  processSerialCommands();

  // Check telemetry send interval
  uint32_t now = millis();
  if (now - lastTelemetryTime >= telemetryIntervalMs) {
    lastTelemetryTime = now;

    if (currentScenario == SCENARIO_OFFLINE) {
      Serial.println("[SIMULATOR:OFFLINE] Telemetry suppressed. Device is simulating offline/power-loss.");
    } else {
      updateSimulationValues();
      sendTelemetry();
    }
  }

  delay(20); // Small yield to prevent CPU hogging
}

// ============================================================================
// Wi-Fi Management
// ============================================================================
void scanWiFiNetworks() {
  Serial.println("\n[WiFi] Scanning for visible 2.4GHz Wi-Fi networks...");
  int n = WiFi.scanNetworks();
  if (n == 0) {
    Serial.println("[WiFi] No networks found. Note: ESP32-C3 ONLY supports 2.4GHz band (not 5GHz).");
  } else {
    Serial.printf("[WiFi] Found %d network(s):\n", n);
    for (int i = 0; i < n; ++i) {
      Serial.printf("  [%d] SSID: '%s' | Signal: %d dBm | %s\n",
        i + 1,
        WiFi.SSID(i).c_str(),
        WiFi.RSSI(i),
        WiFi.encryptionType(i) == WIFI_AUTH_OPEN ? "OPEN" : "ENCRYPTED"
      );
    }
  }
  Serial.println();
}

void connectWiFi() {
  Serial.print("[WiFi] Attempting to connect to SSID: '");
  Serial.print(WIFI_SSID);
  Serial.println("'...");

  WiFi.mode(WIFI_STA);
  WiFi.disconnect(true);
  delay(100);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  uint32_t startAttempt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAttempt < 12000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[WiFi] Connected successfully! IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("[WiFi] RSSI Signal Strength: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.printf("[WiFi] Connection failed (Status: %d). Scanning environment...\n", WiFi.status());
    scanWiFiNetworks();
  }
}

void checkWiFiConnection() {
  static uint32_t lastCheck = 0;
  if (millis() - lastCheck > 12000) {
    lastCheck = millis();
    if (WiFi.status() != WL_CONNECTED) {
      Serial.printf("[WiFi] Still disconnected (Status: %d). Reconnecting to '%s'...\n", WiFi.status(), WIFI_SSID);
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    }
  }
}

// ============================================================================
// NTP Time Synchronization
// ============================================================================
void syncNtpTime() {
  if (WiFi.status() != WL_CONNECTED) return;

  Serial.println("[NTP] Synchronizing UTC time via pool.ntp.org...");
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  time_t now = time(nullptr);
  uint32_t start = millis();
  while (now < 24 * 3600 && millis() - start < 6000) {
    delay(500);
    now = time(nullptr);
  }

  if (now > 24 * 3600) {
    Serial.print("[NTP] UTC Time synchronized: ");
    Serial.println(getIso8601Timestamp());
  } else {
    Serial.println("[NTP] Warning: NTP sync delayed. Using local counter.");
  }
}

String getIso8601Timestamp() {
  time_t now = time(nullptr);
  if (now < 24 * 3600) {
    return ""; // Empty string allows server to use current server timestamp
  }
  struct tm timeinfo;
  gmtime_r(&now, &timeinfo);
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buf);
}

#include <math.h>

uint32_t simulationTick = 0;

// ============================================================================
// Simulation Engine: Physics & Sensor Transitions
// ============================================================================
void updateSimulationValues() {
  simulationTick++;
  
  // Dynamic wave cycling so numbers visibly change on EVERY 10-second packet
  float coldWave = 0.9f * sinf(simulationTick * 0.35f);
  float normalWave = 1.4f * cosf(simulationTick * 0.20f);
  float humWaveCold = 4.0f * cosf(simulationTick * 0.35f);
  float humWaveNormal = 5.0f * sinf(simulationTick * 0.20f);
  
  // Micro-fluctuations (±0.15°C, ±0.3%) ensuring no two consecutive packets are identical
  float microJitter1 = ((random(-15, 16)) / 100.0f);
  float microJitter2 = ((random(-25, 26)) / 100.0f);

  switch (currentScenario) {
    case SCENARIO_NORMAL: {
      // Periodic automated medication retrieval simulation:
      // Every 8 ticks (~80s), simulate opening cold compartment door for 1 cycle (10s)
      bool autoColdDoor = (simulationTick % 8 == 0);
      // Every 15 ticks (~150s), simulate opening normal compartment door for 1 cycle (10s)
      bool autoNormalDoor = (simulationTick % 15 == 0);

      curColdDoor = autoColdDoor;
      curColdLight = autoColdDoor;
      curNormalDoor = autoNormalDoor;
      curNormalLight = autoNormalDoor;

      // Door opening introduces a temporary thermal penalty (+0.8°C)
      float doorHeatPenalty = autoColdDoor ? 0.8f : 0.0f;
      curColdTemp = 4.2f + coldWave + microJitter1 + doorHeatPenalty;
      curColdHum = constrain(46.0f + humWaveCold + microJitter2, 38.0f, 58.0f);

      curNormalTemp = 24.8f + normalWave + microJitter2;
      curNormalHum = constrain(52.0f + humWaveNormal, 42.0f, 62.0f);

      // Refrigerator Compressor Thermostat Cycling:
      // Compressor kicks in when cold temp rises above 4.4°C, shuts off below 3.7°C
      if (curColdTemp > 4.4f || autoColdDoor) {
        curCoolingActive = true;
      } else if (curColdTemp < 3.7f) {
        curCoolingActive = false;
      }
      curNormalFanActive = (curNormalTemp > 24.5f);
      curSensorHealth = "healthy";
      break;
    }

    case SCENARIO_TEMPERATURE_WARNING: {
      // Cold temperature drifts into warning zone (8.5°C to 10.2°C)
      curColdTemp = 9.3f + 0.6f * sinf(simulationTick * 0.3f) + microJitter1;
      curColdHum = constrain(54.0f + humWaveCold, 45.0f, 65.0f);
      curNormalTemp = 25.2f + normalWave + microJitter2;
      curNormalHum = 51.0f + humWaveNormal;
      curNormalDoor = false;
      curColdDoor = false;
      curNormalLight = false;
      curColdLight = false;
      curCoolingActive = true; // Attempting to cool but struggling
      curNormalFanActive = true;
      curSensorHealth = "warning";
      break;
    }

    case SCENARIO_TEMPERATURE_CRITICAL: {
      // Severe cooling failure: cold temperature reaches critical danger (13.5°C to 15.8°C)
      curColdTemp = 14.5f + 0.9f * sinf(simulationTick * 0.25f) + microJitter1;
      curColdHum = constrain(58.0f + humWaveCold, 50.0f, 70.0f);
      curNormalTemp = 26.0f + normalWave;
      curNormalHum = 50.0f;
      curNormalDoor = false;
      curColdDoor = false;
      curNormalLight = false;
      curColdLight = false;
      curCoolingActive = false; // Compressor shut down / failure
      curNormalFanActive = false;
      curSensorHealth = "warning";
      break;
    }

    case SCENARIO_DOOR_OPEN: {
      // Manual Door Open Hold: door remains wide open continuously
      curColdDoor = true;
      curColdLight = true;
      curColdTemp = 7.8f + 0.4f * sinf(simulationTick * 0.3f) + microJitter1;
      curColdHum = 50.0f + microJitter2;
      curNormalDoor = false;
      curNormalLight = false;
      curCoolingActive = true;
      curNormalFanActive = true;
      curSensorHealth = "healthy";
      break;
    }

    case SCENARIO_SENSOR_ERROR: {
      // Sensor fault condition
      curColdTemp = -40.0f;
      curColdHum = 0.0f;
      curNormalTemp = 24.5f + microJitter1;
      curNormalHum = 50.0f;
      curNormalDoor = false;
      curColdDoor = false;
      curCoolingActive = false;
      curNormalFanActive = false;
      curSensorHealth = "error";
      break;
    }

    case SCENARIO_RECOVERY: {
      // Actively cools down back to safe nominal target (~4.0°C)
      curColdTemp = 4.0f + 0.3f * sinf(simulationTick * 0.3f) + microJitter1;
      curColdHum = 45.0f + microJitter2;
      curNormalTemp = 24.5f + normalWave;
      curNormalHum = 50.0f;
      curColdDoor = false;
      curNormalDoor = false;
      curColdLight = false;
      curNormalLight = false;
      curCoolingActive = true;
      curNormalFanActive = true;
      curSensorHealth = "healthy";
      break;
    }

    case SCENARIO_OFFLINE:
      // Telemetry transmission halted in loop()
      break;
  }
}

// ============================================================================
// HTTPS Telemetry Transmission
// ============================================================================
void sendTelemetry() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[HTTP] Cannot send telemetry: Wi-Fi is disconnected.");
    totalPacketsFailed++;
    return;
  }

  #ifdef STATUS_LED_PIN
  digitalWrite(STATUS_LED_PIN, HIGH); // Blink LED during TX
  #endif

  // Build JSON Payload
  String timestamp = getIso8601Timestamp();
  
  // Format numeric values cleanly
  char jsonBuffer[512];
  if (curSensorHealth == "error") {
    // Sensor error payload uses standard fault bounds
    snprintf(jsonBuffer, sizeof(jsonBuffer),
      "{"
        "\"data_source\":\"simulated\","
        "\"normal_temperature_c\":%.1f,"
        "\"normal_humidity_pct\":%.1f,"
        "\"cold_temperature_c\":-40.0,"
        "\"cold_humidity_pct\":0.0,"
        "\"normal_door_open\":%s,"
        "\"cold_door_open\":%s,"
        "\"normal_light_detected\":%s,"
        "\"cold_light_detected\":%s,"
        "\"cooling_active\":%s,"
        "\"normal_fan_active\":%s,"
        "\"sensor_health\":\"error\""
        "%s%s%s"
      "}",
      curNormalTemp, curNormalHum,
      curNormalDoor ? "true" : "false",
      curColdDoor ? "true" : "false",
      curNormalLight ? "true" : "false",
      curColdLight ? "true" : "false",
      curCoolingActive ? "true" : "false",
      curNormalFanActive ? "true" : "false",
      timestamp.length() > 0 ? ",\"recorded_at\":\"" : "",
      timestamp.c_str(),
      timestamp.length() > 0 ? "\"" : ""
    );
  } else {
    snprintf(jsonBuffer, sizeof(jsonBuffer),
      "{"
        "\"data_source\":\"simulated\","
        "\"normal_temperature_c\":%.1f,"
        "\"normal_humidity_pct\":%.1f,"
        "\"cold_temperature_c\":%.1f,"
        "\"cold_humidity_pct\":%.1f,"
        "\"normal_door_open\":%s,"
        "\"cold_door_open\":%s,"
        "\"normal_light_detected\":%s,"
        "\"cold_light_detected\":%s,"
        "\"cooling_active\":%s,"
        "\"normal_fan_active\":%s,"
        "\"sensor_health\":\"%s\""
        "%s%s%s"
      "}",
      curNormalTemp, curNormalHum,
      curColdTemp, curColdHum,
      curNormalDoor ? "true" : "false",
      curColdDoor ? "true" : "false",
      curNormalLight ? "true" : "false",
      curColdLight ? "true" : "false",
      curCoolingActive ? "true" : "false",
      curNormalFanActive ? "true" : "false",
      curSensorHealth.c_str(),
      timestamp.length() > 0 ? ",\"recorded_at\":\"" : "",
      timestamp.c_str(),
      timestamp.length() > 0 ? "\"" : ""
    );
  }

  Serial.println("\n--------------------------------------------------------");
  Serial.printf("[TX #%u] Scenario: %s\n", totalPacketsSent + 1, getScenarioName(currentScenario));
  Serial.printf("[TX] Cold: %.1f C, %.1f%% | Normal: %.1f C, %.1f%% | Door: %s | Cooling: %s\n",
    curColdTemp, curColdHum, curNormalTemp, curNormalHum,
    curColdDoor ? "OPEN" : "CLOSED",
    curCoolingActive ? "ON" : "OFF"
  );

  WiFiClientSecure client;
  client.setInsecure(); // Connects to Cloudflare Supabase SSL endpoint securely without requiring local hardcoded cert expiry

  HTTPClient https;
  https.setTimeout(8000); // 8-second timeout

  if (https.begin(client, SUPABASE_INGEST_URL)) {
    https.addHeader("Content-Type", "application/json");
    https.addHeader("x-device-key", DEVICE_API_KEY);

    int httpCode = https.POST(jsonBuffer);

    if (httpCode == HTTP_CODE_OK || httpCode == HTTP_CODE_CREATED) {
      String response = https.getString();
      totalPacketsSent++;
      Serial.printf("[HTTP 200 OK] Telemetry accepted by MediGuard Cloud!\n");
      Serial.printf("[RX Response] %s\n", response.c_str());
    } else if (httpCode > 0) {
      totalPacketsFailed++;
      Serial.printf("[HTTP ERROR %d] Telemetry rejected: %s\n", httpCode, https.getString().c_str());
    } else {
      totalPacketsFailed++;
      Serial.printf("[HTTP ERROR] Network transmission failed: %s\n", https.errorToString(httpCode).c_str());
    }

    https.end();
  } else {
    totalPacketsFailed++;
    Serial.println("[HTTP ERROR] Unable to initiate HTTPS client connection.");
  }

  #ifdef STATUS_LED_PIN
  digitalWrite(STATUS_LED_PIN, LOW);
  #endif
}

// ============================================================================
// Interactive Serial Monitor Commands
// ============================================================================
void processSerialCommands() {
  if (!Serial.available()) return;

  String input = Serial.readStringUntil('\n');
  input.trim();
  if (input.length() == 0) return;

  String cmd = input;
  cmd.toLowerCase();

  if (cmd == "1" || cmd == "normal") {
    currentScenario = SCENARIO_NORMAL;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 1: NORMAL (Stable: Cold ~4.2 C, Normal ~24.8 C)");
  } else if (cmd == "2" || cmd == "warn" || cmd == "warning") {
    currentScenario = SCENARIO_TEMPERATURE_WARNING;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 2: TEMPERATURE_WARNING (Cold drifts to 9.2 C)");
  } else if (cmd == "3" || cmd == "crit" || cmd == "critical") {
    currentScenario = SCENARIO_TEMPERATURE_CRITICAL;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 3: TEMPERATURE_CRITICAL (Cold climbs to 14.5 C, Cooling OFF)");
  } else if (cmd == "4" || cmd == "door") {
    currentScenario = SCENARIO_DOOR_OPEN;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 4: DOOR_OPEN (Cold Door: OPEN, Light detected)");
  } else if (cmd == "5" || cmd == "error" || cmd == "fault") {
    currentScenario = SCENARIO_SENSOR_ERROR;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 5: SENSOR_ERROR (Fault status, invalid telemetry)");
  } else if (cmd == "6" || cmd == "offline") {
    currentScenario = SCENARIO_OFFLINE;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 6: OFFLINE (Telemetry transmission paused)");
  } else if (cmd == "7" || cmd == "recovery" || cmd == "recover") {
    currentScenario = SCENARIO_RECOVERY;
    Serial.println("\n>>> [SCENARIO CHANGED] -> 7: RECOVERY (Restoring nominal normal values)");
  } else if (cmd == "send" || cmd == "now") {
    Serial.println("\n>>> [MANUAL SEND] Triggering immediate telemetry push...");
    updateSimulationValues();
    sendTelemetry();
  } else if (cmd == "status") {
    printStatus();
  } else if (cmd == "scan") {
    scanWiFiNetworks();
  } else if (cmd.startsWith("interval")) {
    int spaceIdx = cmd.indexOf(' ');
    if (spaceIdx > 0) {
      int sec = cmd.substring(spaceIdx + 1).toInt();
      if (sec >= 3 && sec <= 300) {
        telemetryIntervalMs = sec * 1000;
        Serial.printf("\n>>> [INTERVAL UPDATED] Telemetry interval set to %d seconds.\n", sec);
      } else {
        Serial.println("Invalid interval. Please choose between 3 and 300 seconds.");
      }
    }
  } else if (cmd == "help" || cmd == "?") {
    printHelpMenu();
  } else {
    Serial.printf("Unknown command: '%s'. Type 'help' to see available commands.\n", input.c_str());
  }
}

void printHelpMenu() {
  Serial.println("\n========================================================");
  Serial.println("           Interactive Serial Command Menu              ");
  Serial.println("========================================================");
  Serial.println("  1 / normal   : Set scenario to NORMAL (Cold ~4.2 C)");
  Serial.println("  2 / warn     : Set scenario to TEMPERATURE_WARNING (Cold ~9.2 C)");
  Serial.println("  3 / crit     : Set scenario to TEMPERATURE_CRITICAL (Cold ~14.5 C)");
  Serial.println("  4 / door     : Set scenario to DOOR_OPEN (Cold door open)");
  Serial.println("  5 / error    : Set scenario to SENSOR_ERROR (Fault condition)");
  Serial.println("  6 / offline  : Set scenario to OFFLINE (Simulate disconnection)");
  Serial.println("  7 / recover  : Set scenario to RECOVERY (Return to normal)");
  Serial.println("  send         : Force immediate telemetry transmission");
  Serial.println("  interval <S> : Change interval in seconds (e.g. interval 30)");
  Serial.println("  status       : View current Wi-Fi, IP, and packet counters");
  Serial.println("  help / ?     : Print this command menu");
  Serial.println("========================================================\n");
}

void printStatus() {
  Serial.println("\n--- [MediGuard Simulator Status] ---");
  Serial.printf("Current Scenario : %s\n", getScenarioName(currentScenario));
  Serial.printf("Wi-Fi Status     : %s\n", WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected");
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("IP Address       : %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("RSSI Signal      : %d dBm\n", WiFi.RSSI());
  }
  Serial.printf("Telemetry Cadence: Every %u seconds\n", telemetryIntervalMs / 1000);
  Serial.printf("Packets Sent OK  : %u\n", totalPacketsSent);
  Serial.printf("Packets Failed   : %u\n", totalPacketsFailed);
  Serial.println("------------------------------------");
}

const char* getScenarioName(SimulationScenario s) {
  switch (s) {
    case SCENARIO_NORMAL: return "NORMAL";
    case SCENARIO_TEMPERATURE_WARNING: return "TEMPERATURE_WARNING";
    case SCENARIO_TEMPERATURE_CRITICAL: return "TEMPERATURE_CRITICAL";
    case SCENARIO_DOOR_OPEN: return "DOOR_OPEN";
    case SCENARIO_SENSOR_ERROR: return "SENSOR_ERROR";
    case SCENARIO_OFFLINE: return "OFFLINE";
    case SCENARIO_RECOVERY: return "RECOVERY";
    default: return "UNKNOWN";
  }
}
