#ifndef MEDIGUARD_CONFIG_H
#define MEDIGUARD_CONFIG_H

// ============================================================================
// MediGuard ESP32-C3 Simulator - Configuration
// Edit this file to customize Wi-Fi and Supabase Ingestion settings.
// ============================================================================

// 1. Wi-Fi Credentials
#define WIFI_SSID       "medigurd"
#define WIFI_PASSWORD   "123123123"

// 2. Supabase Telemetry Ingestion Endpoint
// This points to the deployed Supabase Edge Function
#define SUPABASE_INGEST_URL "https://bskjisnvumbsiwcahvyw.supabase.co/functions/v1/ingest-telemetry"

// 3. Dedicated Device API Key
// Generated and authenticated by the server against public.devices
#define DEVICE_API_KEY  "mg_dev_sec_c3_test_987654321"

// 4. Default Telemetry Interval (in seconds)
// Can be changed dynamically via Serial Monitor by typing 'interval <seconds>'
#define DEFAULT_TELEMETRY_INTERVAL_SEC  10

// 5. Hardware / Board Settings for ESP32-C3
#define SERIAL_BAUD_RATE    115200

// Optional on-board status LED (ESP32-C3 DevKitM-1 typically uses GPIO 8 or RGB LED)
#define STATUS_LED_PIN      8

#endif // MEDIGUARD_CONFIG_H
