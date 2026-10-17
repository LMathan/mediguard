# ESP32 Hardware Integration Specification — MediGuard

## 1. Hardware Architecture Overview

The MediGuard physical prototype will use an **ESP32 DevKit V1** micro-controller orchestrating two physical compartments:
1. **Normal Storage Compartment** (target 15°C - 25°C).
2. **Cold Storage Compartment** (target 2°C - 8°C).

### Connected Hardware Components:
- **RFID Reader**: 1x MFRC522 (SPI) at the medicine check-in slot.
- **Sensors**:
  - 2x DHT22 / AM2302 (One per compartment: temperature & relative humidity).
  - 2x LDR (Light-Dependent Resistors: detects internal light exposure).
  - 2x Magnetic Reed Switches (Normally-open, door state detection: open/closed).
- **Actuators & Indicators**:
  - 1x 0.96" I2C OLED Display (SSD1306, 128x64 px) for current readings and status.
  - 1x Active Buzzer + 2x Bi-color LEDs for auditory and visual warnings.
  - 1x Peltier TEC1-12706 cooling assembly with heatsink and exhaust fan.
  - 1x Internal circulation fan and relay/MOSFET drivers.

---

## 2. Telemetry Schema & Payload Format

The ESP32 communicates over secure HTTPS POST or MQTT over TLS. Each telemetry packet strictly follows this JSON schema:

```json
{
  "device_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "data_source": "hardware",
  "recorded_at": "2026-10-17T06:30:00.000Z",
  "normal_temperature_c": 21.4,
  "normal_humidity_pct": 49.2,
  "cold_temperature_c": 4.6,
  "cold_humidity_pct": 53.8,
  "normal_light_detected": false,
  "cold_light_detected": false,
  "normal_door_open": false,
  "cold_door_open": false,
  "cooling_active": true,
  "normal_fan_active": true,
  "sensor_health": "healthy"
}
```

### Sensor Health States:
- `healthy`: All sensors responding normally.
- `warning`: Transient checksum failure or one DHT22 retry needed.
- `error`: Sensor unreachable, disconnected, or out-of-range (>80°C or <-40°C).

---

## 3. Security & Device Authentication

### Critical Security Rule:
**Never embed the Supabase `service_role` secret in the ESP32 firmware.**

### Recommended Ingestion Architecture:
1. **Device Tokens**: Each ESP32 is provisioned with a unique, revocable Device Secret Token (or Supabase Auth device service user session).
2. **Supabase Edge Function (`/ingest-telemetry`)**:
   - The ESP32 sends telemetry to a custom Supabase Edge Function (`https://bskjisnvumbsiwcahvyw.supabase.co/functions/v1/ingest-telemetry`).
   - The function authenticates the `X-Device-Token` header, checks device ownership in `public.devices`, and inserts into `public.sensor_readings`.
   - The user's mobile app receives real-time updates via Supabase Realtime subscriptions without exposing database write credentials to the device.

---

## 4. Telemetry Cadence & Offline Handling

1. **Local Control Loop (1 Hz - 2 Hz)**:
   - Read DHT22 and reed switches every 1–2 seconds.
   - Adjust Peltier PWM and fan relay locally via hysteresis (target 4.0°C ± 1.5°C).
   - If door is left open > 60 seconds, trigger local buzzer and red LED.
2. **Cloud Uplink Cadence (30 - 60 seconds)**:
   - Transmit telemetry every 30 seconds under normal operation.
   - **Immediate Event Uplink**: Instantly send an event packet upon door open/close transition or RFID tag scan.
3. **Network Failure & Retries**:
   - In case of Wi-Fi loss, buffer up to 100 historical readings in ESP32 SPIFFS/LittleFS flash memory.
   - Reconnection uses exponential backoff (2s, 4s, 8s, up to 60s max).
   - Once reconnected, drain the buffered readings with original `recorded_at` timestamps.

---

## 5. RFID & Inventory Confirmation Flow

1. An RFID card/vial tag is brought to the RC522 reader.
2. The ESP32 reads the 4-byte or 7-byte UID (e.g. `E28011700000020`) and sounds a short 50ms beep.
3. The UID is sent to the app / Supabase via the inventory event channel.
4. **Physical Safety Boundary**:
   - A reed switch only indicates physical door position (open/closed). It does not guarantee medicine weight or presence.
   - Therefore, the mobile application explicitly records `confirmation_method = 'app'` or physical button confirmation, and classifies the stock change as `user-confirmed inventory`.
   - If the door is opened and closed without app confirmation, the transaction remains `pending` and does not silently update the database.

---

## 6. Safe Separation: Telemetry vs. Remote Actuator Control

- Actuators (cooling, fans, relays) are governed by an autonomous firmware-level safety watchdog.
- Cloud commands cannot override safety cutoffs (e.g. thermal overload protection at 50°C heatsink temp).
- Any remote parameter update (e.g. changing target threshold) requires signature validation and is logged in `device_settings`.

---

## 7. Migration from `DemoSensorService` to `HardwareSensorService`

The MediGuard mobile application implements an interface:
```dart
abstract class SensorDataSource {
  Stream<SensorReading> get readingStream;
  SensorReading get latestReading;
  bool get isSimulated;
  Future<void> initialize();
  Future<void> dispose();
}
```

- When using `DemoSensorService`, all readings have `dataSource = DataSourceType.simulated`.
- When switching to `HardwareSensorService`, the provider switches to listening to the Supabase `sensor_readings` realtime stream for the active `device_id`.
- The entire UI, alert engine, charts, and state remain identical and require **zero UI code changes**.
