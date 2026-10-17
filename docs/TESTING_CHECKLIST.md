# MediGuard Testing Checklist & Quality Verification

This checklist outlines the verification steps required to ensure code quality, functional safety, and architectural integrity.

---

## 1. Automated Test Suite

Run all automated tests:
```bash
flutter test
```

### Key Test Categories:
- [x] **Threshold Evaluation**: Checks whether normal (15-25°C) and cold (2-8°C) readings are correctly classified as Normal, Warning, or Critical.
- [x] **Overall Device Status Calculation**: Verifies that stale data (>90s) or missing sensors yield `Unknown/Offline`, never false `Normal`.
- [x] **Alert Deduplication**: Verifies that repeated high-temperature readings do not produce duplicate alert records.
- [x] **Expiry Calculation**: Verifies detection of expired medicines and nearing-expiry items within the user's warning window.
- [x] **Transaction State Transitions**: Verifies that cancelling a pending transaction reverts medicine status without altering stock.
- [x] **Data Source Tagging**: Asserts that `DemoSensorService` never produces readings with `DataSourceType.hardware`.
- [x] **Widget Smoke Tests**: Ensures Dashboard renders demo badge, inventory search responds properly, and alerts can be acknowledged.

---

## 2. Static Analysis & Formatting

```bash
# Code format check
dart format --output=none --set-exit-if-changed .

# Static analysis
flutter analyze
```

Target: `No issues found!`

---

## 3. Manual Supabase Integration Checklist

| Step | Test Action | Expected Result |
| :--- | :--- | :--- |
| **Auth** | Sign up with new email and password | Profile created in `public.profiles` via database trigger |
| **RLS Isolation** | Log in as User A, register medicine, log in as User B | User B cannot view or modify User A's medicine |
| **Inventory Add** | Scan/Enter RFID UID, confirm addition | Atomic transaction created (`status = confirmed`), medicine added |
| **Inventory Cancel** | Start removal, click Cancel | Transaction marked `cancelled`, quantity untouched |
| **Realtime** | Modify medicine in one client | Other client updates automatically without full refresh |
| **Offline Mode** | Turn on airplane mode | App retains cached data, shows offline indicator, prevents silent failures |

---

## 4. Build Verification

Build Android Debug APK:
```bash
flutter build apk --debug
```

Expected result: `build/app/outputs/flutter-apk/app-debug.apk` built successfully.
