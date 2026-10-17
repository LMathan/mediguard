# Supabase Setup Guide for MediGuard

This guide details how to set up, secure, and configure the Supabase backend for the **MediGuard** application.

---

## 1. Project Reference & Connection
- **Project Ref**: `bskjisnvumbsiwcahvyw`
- **Default Project URL**: `https://bskjisnvumbsiwcahvyw.supabase.co`

### Using the Supabase MCP Server
Antigravity connects to Supabase through the MCP server configured in `~/.gemini/antigravity/mcp_config.json`:
```json
{
  "mcpServers": {
    "supabase": {
      "serverUrl": "https://mcp.supabase.com/mcp?project_ref=bskjisnvumbsiwcahvyw&features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching"
    }
  }
}
```

---

## 2. Applying Database Migrations

The full migration script is located at:
`supabase/migrations/20261017000001_create_mediguard_schema.sql`

### Option A: Using the Supabase Web Dashboard SQL Editor
1. Log in to [https://supabase.com/dashboard/project/bskjisnvumbsiwcahvyw](https://supabase.com/dashboard/project/bskjisnvumbsiwcahvyw).
2. Navigate to the **SQL Editor** tab from the left sidebar.
3. Click **New query**.
4. Open `supabase/migrations/20261017000001_create_mediguard_schema.sql`, copy its entire contents, paste it into the editor, and click **Run**.
5. Verify the following 7 tables are created under the `public` schema:
   - `profiles`
   - `devices`
   - `device_settings`
   - `medicines`
   - `sensor_readings`
   - `inventory_transactions`
   - `alerts`

### Option B: Using Supabase CLI
```bash
npx supabase link --project-ref bskjisnvumbsiwcahvyw
npx supabase db push
```

---

## 3. Database Security & Row Level Security (RLS)

All tables enforce Row Level Security (`ENABLE ROW LEVEL SECURITY`).

| Table | Policies | Enforced Rule |
| :--- | :--- | :--- |
| `profiles` | SELECT, INSERT, UPDATE | `auth.uid() = id` |
| `devices` | ALL (SELECT, INSERT, UPDATE, DELETE) | `auth.uid() = user_id` |
| `device_settings` | ALL | `auth.uid() = user_id` |
| `medicines` | ALL | `auth.uid() = user_id` |
| `sensor_readings`| ALL | `auth.uid() = user_id` |
| `inventory_transactions` | ALL | `auth.uid() = user_id` |
| `alerts` | ALL | `auth.uid() = user_id` |

### Critical Security Practices
1. **Never use `service_role` in client code**: The Flutter mobile app must only use the public `anon` key. All data operations are checked by Postgres RLS using the JWT token issued upon login.
2. **Atomic Confirmation**: The database function `confirm_inventory_transaction(p_transaction_id UUID, p_confirm BOOLEAN, p_notes TEXT)` uses `SECURITY DEFINER` with `SET search_path = public` and explicit row locks (`FOR UPDATE`) to guarantee that medicine quantity adjustments and status changes happen atomically.
3. **No Unauthenticated Telemetry Ingestion**: The schema restricts inserts to the authenticated user owning the device. For physical hardware (ESP32), see [HARDWARE_INTEGRATION.md](./HARDWARE_INTEGRATION.md).

---

## 4. Enabling Realtime

The migration automatically attempts to publish tables to `supabase_realtime`:
- `medicines`
- `alerts`
- `sensor_readings`
- `inventory_transactions`
- `devices`

To verify in Dashboard:
1. Go to **Database** > **Publications**.
2. Select `supabase_realtime`.
3. Confirm that the tables are toggled ON.

---

## 5. Setting up Authentication

1. In Supabase Dashboard, navigate to **Authentication** > **Providers**.
2. Ensure **Email** is enabled.
3. (Recommended for development) Go to **Authentication** > **URL Configuration** and **Email Templates**, and if desired, disable email confirmation for instant local testing under **Authentication** > **Providers** > **Email** > uncheck "Confirm email".

---

## 6. Seeding Test Data (Optional)

Once you create an account via the MediGuard app or the Supabase Auth dashboard:
1. Open the SQL Editor.
2. Run `supabase/seed.sql`.
3. It will automatically attach demo medicines (e.g., Insulin Glargine, Augmentin ES, Panadol), 2 hours of baseline readings, and active alerts to the first user found in `auth.users`.
