# MediGuard ESP32-C3 Hardware Simulator

Firmware simulator running on the **ESP32-C3** (RISC-V 160MHz) development board. It generates realistic, bounded telemetry for both **normal** and **cold storage compartments**, and transmits authenticated JSON payloads over HTTPS to the MediGuard Supabase Cloud pipeline.

---

## 1. Quick Setup & Configuration

### A. Wi-Fi & Endpoint Credentials
Open [`config.h`](file:///Users/aitech/Documents/App/MediGuard/firmware/esp32_c3_mediguard_simulator/config.h) in this directory:

```cpp
// 1. Wi-Fi Credentials
#define WIFI_SSID       "medigurd"
#define WIFI_PASSWORD   "123123123"

// 2. Supabase Telemetry Ingestion Endpoint
#define SUPABASE_INGEST_URL "https://bskjisnvumbsiwcahvyw.supabase.co/functions/v1/ingest-telemetry"

// 3. Dedicated Device API Key (Registered in public.devices)
#define DEVICE_API_KEY  "mg_dev_sec_c3_test_987654321"

// 4. Default Telemetry Interval (seconds)
#define DEFAULT_TELEMETRY_INTERVAL_SEC  10
```

---

## 2. Flashing the Firmware

### Option A: Using Arduino IDE
1. Open **Arduino IDE**.
2. Go to **Tools > Board > esp32 > ESP32C3 Dev Module** (or install *esp32 by Espressif Systems* via Boards Manager).
3. Set **Tools > USB CDC On Boot** to **Enabled** (essential for ESP32-C3 Serial Monitor).
4. Select your connected USB Port (**Tools > Port**).
5. Open [`esp32_c3_mediguard_simulator.ino`](file:///Users/aitech/Documents/App/MediGuard/firmware/esp32_c3_mediguard_simulator/esp32_c3_mediguard_simulator.ino).
6. Click **Upload** (➡️).
7. Open **Serial Monitor** at **115200 baud**.

### Option B: Using PlatformIO (VS Code / CLI)
Run the following command from this directory:
```bash
pio run --target upload
pio device monitor -b 115200
```

---

## 3. Interactive Serial Monitor Commands

When the ESP32-C3 boots, it displays the interactive console menu. You can test each clinical scenario by typing commands into the Serial Monitor:

| Command | Scenario | Simulated Behavior |
| :--- | :--- | :--- |
| `1` or `normal` | **NORMAL** | Cold: ~4.2°C, Normal: ~24.8°C, Doors: Closed, Cooling: Active. |
| `2` or `warn` | **TEMP WARNING** | Cold temperature drifts up to **9.2°C** (exceeds 8.0°C limit). |
| `3` or `crit` | **TEMP CRITICAL** | Cold temperature reaches **14.5°C**, cooling compressor OFF. |
| `4` or `door` | **DOOR OPEN** | Cold door: **OPEN**, light detected, temp climbs to ~7.8°C. |
| `5` or `error` | **SENSOR FAULT** | Sensor status: **error**, cold temp reports fault sentinel. |
| `6` or `offline` | **OFFLINE** | Halts telemetry transmissions; allows app to detect stale/offline. |
| `7` or `recover` | **RECOVERY** | Smoothly cools back down to safe baseline (Cold ~4.0°C). |
| `send` | **IMMEDIATE TX** | Forces an immediate telemetry transmission without waiting for timer. |
| `interval <S>` | **INTERVAL** | Sets custom interval in seconds (e.g. `interval 30`). |
| `status` | **STATUS** | Prints Wi-Fi IP, RSSI signal, packet counters, and active scenario. |
| `help` | **HELP MENU** | Displays available commands. |

---

## 4. Telemetry Payload Format

The simulator transmits the following JSON schema accepted by `ingest-telemetry`:

```json
{
  "data_source": "simulated",
  "normal_temperature_c": 24.8,
  "normal_humidity_pct": 52.0,
  "cold_temperature_c": 4.2,
  "cold_humidity_pct": 46.0,
  "normal_door_open": false,
  "cold_door_open": false,
  "normal_light_detected": false,
  "cold_light_detected": false,
  "cooling_active": true,
  "normal_fan_active": true,
  "sensor_health": "healthy",
  "recorded_at": "2026-10-17T07:58:07Z"
}
```

---

## 5. Security & Authentication Architecture

1. **Per-Device Credential**: The ESP32 authenticates via `x-device-key: mg_dev_sec_c3_test_987654321`.
2. **Server-Side Ownership**: The Edge Function resolves `device_id` and `user_id` strictly from `public.devices`. The microcontroller cannot inject an arbitrary `user_id`.
3. **No Secrets in Logs**: Wi-Fi passwords and device API keys are never printed to the Serial Monitor.
4. **HTTPS Encryption**: All telemetry is encrypted via TLS 1.3 to the Cloudflare Supabase gateway.
