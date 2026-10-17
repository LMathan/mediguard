# MediGuard — Smart Medicine Storage and Monitoring System

MediGuard is an IoT-enabled mobile healthcare monitoring and inventory management application built with **Flutter**, **Supabase**, and **Riverpod**.

Designed specifically for dual-compartment pharmaceutical storage units:
1. **Normal Compartment**: Room temperature storage (15°C - 25°C) for dry medications, antibiotics, and tablets.
2. **Cold Compartment**: Refrigerated storage (2°C - 8°C) for vaccines, insulins, biologics, and eye drops.

---

## 🌟 Key Features

- **Real-Time Telemetry Dashboard**: Live monitoring of temperature, relative humidity, door switches, and actuator states (Peltier cooler and circulation fans).
- **Two-Phase Inventory Workflows**: Explicit, recoverable transaction workflows for medicine inbound (add) and outbound (dispense) with RFID tag validation and door cycle verification.
- **Auditable History & Timeline**: Unified activity audit logging medicine restocking, removals, sensor threshold breaches, and alert resolutions.
- **Comprehensive Alert Engine**: Threshold alarms with stable deduplication logic, local device notifications, and acknowledge/resolve states.
- **Autonomous Demo Simulator**: 8 deterministic simulation scenarios (Normal, Warning, Critical, Door Open, Sensor Fault, Stale Data, Offline, Recovery) allowing thorough testing without physical hardware.
- **Future ESP32 Hardware Ready**: Pluggable `SensorDataSource` architecture allowing seamless transition to real micro-controller telemetry.

---

## 🚀 Quick Start Guide

### 1. Install Dependencies
Ensure you have Flutter 3.44+ installed:
```bash
flutter pub get
```

### 2. Configure Supabase Environment
Copy `.env.example` to `.env` or provide compilation flags:
```bash
cp .env.example .env
```

To run with live Supabase cloud sync:
```bash
flutter run --dart-define=SUPABASE_URL=https://bskjisnvumbsiwcahvyw.supabase.co --dart-define=SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
```

> **Note**: If `SUPABASE_ANON_KEY` is not provided, MediGuard launches automatically in **Interactive Demo Mode** with in-memory simulation, pre-seeded clinical inventory, and full feature availability.

### 3. Apply Database Migrations
Migrations and seed scripts are located in `supabase/`:
- Migration file: `supabase/migrations/20261017000001_create_mediguard_schema.sql`
- Seed test fixtures: `supabase/seed.sql`

To apply via the Supabase Dashboard:
1. Open the [Supabase SQL Editor](https://supabase.com/dashboard/project/bskjisnvumbsiwcahvyw).
2. Paste the contents of `20261017000001_create_mediguard_schema.sql` and run.
3. Review detailed step-by-step instructions in [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md).

### 4. Run the App in Demo Mode
```bash
flutter run
```
You can switch scenarios at any time via the **Sim Controls** button on the top banner or through **Settings > Simulation Control Panel**.

### 5. Run Automated Tests
```bash
flutter test
```
Runs unit tests for threshold boundaries, alert deduplication, medicine expiry, inventory transactions, and widget rendering smoke tests.

### 6. Static Analysis and Formatting
```bash
flutter analyze
dart format .
```

### 7. Build Debug Android APK
```bash
flutter build apk --debug
```
Output: `build/app/outputs/flutter-apk/app-debug.apk`

---

## 🏗️ Architecture & Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Clean feature-first design, state management, and data flow.
- [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) — Postgres schema, RLS policies, atomic functions, and Realtime setup.
- [docs/HARDWARE_INTEGRATION.md](docs/HARDWARE_INTEGRATION.md) — ESP32 DevKit V1 hardware pinout, sensor telemetry schema, and secure ingestion.
- [docs/TESTING_CHECKLIST.md](docs/TESTING_CHECKLIST.md) — Quality verification checklist and test plan.

---

## 🔒 Security Best Practices

1. **No Secrets in Source Control**: `.env` and sensitive files are ignored via `.gitignore`.
2. **Never expose `service_role`**: The Flutter mobile app strictly uses the public `anon` key. Row Level Security (RLS) ensures clinicians only access their authorized records.
3. **Atomic Confirmations**: Transactions are executed with PostgreSQL row locking (`FOR UPDATE`) to prevent race conditions or duplicate stock updates.
