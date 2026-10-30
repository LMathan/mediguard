import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ONE_SIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "";
const ONE_SIGNAL_REST_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") || "";

async function sendOneSignalPush(userId: string, title: string, message: string, data: Record<string, unknown> = {}) {
  try {
    const res = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": `Basic ${ONE_SIGNAL_REST_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONE_SIGNAL_APP_ID,
        include_aliases: {
          external_id: [userId],
        },
        include_external_user_ids: [userId],
        target_channel: "push",
        headings: { en: title },
        contents: { en: message },
        priority: 10,
        data,
      }),
    });
    return await res.json();
  } catch (err) {
    console.error("[OneSignal] Offline push error:", err);
    return null;
  }
}

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(JSON.stringify({ error: "Missing Supabase credentials." }), { status: 500 });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // 1. Find all devices that are marked online but haven't reported in over 60 seconds
  const cutoffTime = new Date(Date.now() - 60 * 1000).toISOString();
  const { data: offlineDevices, error: devError } = await supabase
    .from("devices")
    .select("id, user_id, device_name, serial_number, last_seen_at")
    .eq("is_online", true)
    .lt("last_seen_at", cutoffTime);

  if (devError) {
    return new Response(JSON.stringify({ error: devError.message }), { status: 500 });
  }

  const results = [];

  for (const dev of offlineDevices || []) {
    // 2. Mark device as offline
    await supabase.from("devices").update({ is_online: false }).eq("id", dev.id);

    // 3. Check cooldown: avoid multiple alerts within 5 minutes
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { data: existingAlert } = await supabase
      .from("alerts")
      .select("id")
      .eq("user_id", dev.user_id)
      .eq("device_id", dev.id)
      .eq("type", "device_offline")
      .gte("created_at", fiveMinutesAgo)
      .maybeSingle();

    if (!existingAlert) {
      const title = "⚠️ MediGuard Device Offline!";
      const message = `Storage unit ${dev.device_name || "MediGuard"} has lost connection. No telemetry received for over 60 seconds.`;

      // Insert alert in DB
      await supabase.from("alerts").insert({
        user_id: dev.user_id,
        device_id: dev.id,
        type: "device_offline",
        title: title,
        message: message,
        severity: "critical",
        status: "active",
        data_source: "hardware",
        created_at: new Date().toISOString(),
      });

      // Dispatch OneSignal push
      const pushRes = await sendOneSignalPush(dev.user_id, title, message, {
        alert_type: "device_offline",
        device_id: dev.id,
      });

      results.push({ device_id: dev.id, notified: true, push_res: pushRes });
    } else {
      results.push({ device_id: dev.id, notified: false, reason: "cooldown" });
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      offline_count: (offlineDevices || []).length,
      processed: results,
    }),
    { headers: { "Content-Type": "application/json" } }
  );
});
