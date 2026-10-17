#ifndef MEDIGUARD_CONFIG_H
#define MEDIGUARD_CONFIG_H

// ============================================================================
// MediGuard ESP32-C3 Simulator - Configuration Template
// Copy this file to 'config.h' and fill in your credentials.
// ============================================================================

// 1. Wi-Fi Credentials
#define WIFI_SSID       "YOUR_WIFI_SSID"
#define WIFI_PASSWORD   "YOUR_WIFI_PASSWORD"

// 2. Supabase Telemetry Ingestion Endpoint
#define SUPABASE_INGEST_URL "https://YOUR_PROJECT_REF.supabase.co/functions/v1/ingest-telemetry"

// 3. Dedicated Device API Key
#define DEVICE_API_KEY  "YOUR_DEVICE_API_KEY"

// 4. Default Telemetry Interval (in seconds)
#define DEFAULT_TELEMETRY_INTERVAL_SEC  10

// 5. Hardware Settings
#define SERIAL_BAUD_RATE    115200
#define STATUS_LED_PIN      8

#endif // MEDIGUARD_CONFIG_H
