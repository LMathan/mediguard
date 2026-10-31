import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const ONE_SIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "";
const ONE_SIGNAL_REST_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") || "";

// Helper: dispatch OneSignal push notification to a user
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

    const resJson = await res.json();
    console.log("[OneSignal] Push response:", JSON.stringify(resJson));
    return resJson;
  } catch (err) {
    console.error("[OneSignal] Push error:", err);
    return null;
  }
}

Deno.serve(async (req: Request) => {
  // CORS Headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-device-key",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed. Use POST." }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // 1. Extract and validate Device API Key
  const authHeader = req.headers.get("authorization");
  const deviceKeyHeader = req.headers.get("x-device-key");
  
  let apiKey: string | null = null;
  if (deviceKeyHeader && deviceKeyHeader.trim().length > 0) {
    apiKey = deviceKeyHeader.trim();
  } else if (authHeader && authHeader.startsWith("Bearer ")) {
    apiKey = authHeader.replace("Bearer ", "").trim();
  }

  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "Missing device credential. Provide 'x-device-key' header or 'Bearer <key>'." }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 2. Initialize Supabase Admin Client
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Server configuration error: missing Supabase credentials." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // 3. Authenticate Device via public.devices table
  const { data: device, error: deviceError } = await supabase
    .from("devices")
    .select("id, user_id, device_name, serial_number, is_online")
    .eq("api_key", apiKey)
    .maybeSingle();

  if (deviceError || !device) {
    return new Response(
      JSON.stringify({ error: "Unauthorized: Invalid or unrecognized device key." }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 4. Parse & Validate Ingestion Payload
  let payload: any;
  try {
    payload = await req.json();
  } catch (_e) {
    return new Response(
      JSON.stringify({ error: "Malformed JSON payload." }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 4a. Special Event: RFID Scan Handling
  if (payload.event_type === "rfid_scan") {
    const rawUid = payload.rfid_uid || "";
    const cleanUid = rawUid.toString().trim().toUpperCase();

    if (!cleanUid) {
      return new Response(
        JSON.stringify({ error: "Missing or empty 'rfid_uid' in rfid_scan payload." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const compartment = payload.compartment === "normal" ? "normal" : "cold";
    console.log(`[RFID] Processing scan event: UID=${cleanUid}, Compartment=${compartment}, Device=${device.id}`);

    // Check if this UID is registered in medicines
    const { data: existingMed, error: medError } = await supabase
      .from("medicines")
      .select("id, name, compartment, status")
      .eq("rfid_uid", cleanUid)
      .neq("status", "removed")
      .maybeSingle();

    if (medError) {
      console.error("[RFID] Error querying medicines table:", medError);
    }

    if (existingMed && existingMed.name) {
      console.log(`[RFID] Registered medicine recognized: '${existingMed.name}' (${cleanUid})`);
      return new Response(
        JSON.stringify({
          status: "registered",
          registered: true,
          medicine_name: existingMed.name,
          compartment: existingMed.compartment || compartment,
          rfid_uid: cleanUid,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // UID is NOT registered: Save to public.unregistered_medicines
    const nowIso = new Date().toISOString();

    const { data: existingUnreg } = await supabase
      .from("unregistered_medicines")
      .select("id, scan_count")
      .eq("rfid_uid", cleanUid)
      .maybeSingle();

    const newScanCount = existingUnreg ? (Number(existingUnreg.scan_count) || 1) + 1 : 1;

    const { error: unregError } = await supabase
      .from("unregistered_medicines")
      .upsert({
        rfid_uid: cleanUid,
        compartment: compartment,
        device_id: device.serial_number || device.id || "mediguard-container-01",
        status: "pending",
        scan_count: newScanCount,
        last_scanned_at: nowIso,
      }, { onConflict: "rfid_uid" });

    if (unregError) {
      console.error("[RFID] Failed to insert/update unregistered_medicines:", unregError);
      return new Response(
        JSON.stringify({ error: "Failed to store unregistered RFID tag: " + unregError.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`[RFID] Successfully logged unregistered tag ${cleanUid} to public.unregistered_medicines`);

    return new Response(
      JSON.stringify({
        status: "unregistered",
        registered: false,
        message: "Invalid ID - Logged to unregistered medicines for mobile app enrollment",
        rfid_uid: cleanUid,
        compartment: compartment,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Validate Required Fields & Ranges
  const normalTemp = Number(payload.normal_temperature_c);
  const normalHum = Number(payload.normal_humidity_pct);
  const coldTemp = Number(payload.cold_temperature_c);
  const coldHum = Number(payload.cold_humidity_pct);

  if (isNaN(normalTemp) || isNaN(normalHum) || isNaN(coldTemp) || isNaN(coldHum)) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid numeric temperature/humidity values." }),
      { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (normalTemp < -40 || normalTemp > 85 || coldTemp < -40 || coldTemp > 85) {
    return new Response(
      JSON.stringify({ error: "Temperature value outside physical sensor limits (-40 to +85°C)." }),
      { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (normalHum < 0 || normalHum > 100 || coldHum < 0 || coldHum > 100) {
    return new Response(
      JSON.stringify({ error: "Humidity value outside valid percentage range (0 to 100%)." }),
      { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Validate Enums
  let health = "healthy";
  if (payload.sensor_health === "warning" || payload.sensor_health === "error") {
    health = payload.sensor_health;
  } else if (payload.sensor_status === "error" || payload.sensor_status === "fault") {
    health = "error";
  }

  const dataSource = payload.data_source === "hardware" ? "hardware" : "simulated";
  const recordedAt = payload.recorded_at ? new Date(payload.recorded_at).toISOString() : new Date().toISOString();

  // 5. Atomic Insert into sensor_readings
  const newReading = {
    device_id: device.id,
    user_id: device.user_id,
    normal_temperature_c: normalTemp,
    normal_humidity_pct: normalHum,
    cold_temperature_c: coldTemp,
    cold_humidity_pct: coldHum,
    normal_door_open: Boolean(payload.normal_door_open),
    cold_door_open: Boolean(payload.cold_door_open),
    normal_light_detected: Boolean(payload.normal_light_detected),
    cold_light_detected: Boolean(payload.cold_light_detected),
    cooling_active: Boolean(payload.cooling_active),
    normal_fan_active: Boolean(payload.normal_fan_active),
    sensor_health: health,
    data_source: dataSource,
    recorded_at: recordedAt,
  };

  const { data: inserted, error: insertError } = await supabase
    .from("sensor_readings")
    .insert(newReading)
    .select("id, recorded_at")
    .single();

  if (insertError) {
    return new Response(
      JSON.stringify({ error: "Failed to persist sensor reading: " + insertError.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 6. Update Device Last Seen & Online Status
  await supabase
    .from("devices")
    .update({
      last_seen_at: new Date().toISOString(),
      is_online: true,
      data_source: dataSource,
    })
    .eq("id", device.id);

  // Auto-resolve any active device_offline alerts since device is now verified online
  const nowIso = new Date().toISOString();
  await supabase
    .from("alerts")
    .update({
      status: "resolved",
      resolved_at: nowIso,
    })
    .eq("device_id", device.id)
    .eq("type", "device_offline")
    .eq("status", "active");

  const coldDoorOpen = Boolean(payload.cold_door_open);

  // Auto-resolve nominal temperature alerts if within safe 2.0°C - 8.0°C range
  if (coldTemp >= 2.0 && coldTemp <= 8.0) {
    await supabase
      .from("alerts")
      .update({
        status: "resolved",
        resolved_at: nowIso,
      })
      .eq("device_id", device.id)
      .in("type", ["cold_temp_high", "cold_temp_low", "high_temp", "low_temp"])
      .eq("status", "active");
  }

  // Auto-resolve door alert if cold storage door is shut
  if (!coldDoorOpen) {
    await supabase
      .from("alerts")
      .update({
        status: "resolved",
        resolved_at: nowIso,
      })
      .eq("device_id", device.id)
      .in("type", ["door_open", "door_left_open"])
      .eq("status", "active");
  }

  // Auto-resolve sensor fault if sensors report healthy
  if (health === "healthy") {
    await supabase
      .from("alerts")
      .update({
        status: "resolved",
        resolved_at: nowIso,
      })
      .eq("device_id", device.id)
      .in("type", ["sensor_fault", "sensor_error"])
      .eq("status", "active");
  }

  // 7. Check Critical / Abnormal Conditions & Dispatch OneSignal Push Alert
  const isColdCritical = coldTemp > 8.0 || coldTemp < 2.0;
  const isNormalCritical = normalTemp > 25.0 || normalTemp < 15.0;
  const isSensorFault = health === "error";

  if (isColdCritical || isNormalCritical || coldDoorOpen || isSensorFault) {
    let alertType = "temperature_critical";
    let alertTitle = "🚨 Critical Environmental Alert";
    let alertMsg = "";
    let severity = "critical";

    if (coldTemp > 8.0) {
      alertType = "cold_temp_high";
      alertTitle = "🚨 Cold Compartment Overheating!";
      alertMsg = `Cold temperature rose to ${coldTemp.toFixed(1)}°C (Limit: 8.0°C). Vaccine potency at risk!`;
    } else if (coldTemp < 2.0) {
      alertType = "cold_temp_low";
      alertTitle = "❄️ Cold Compartment Freezing!";
      alertMsg = `Cold temperature dropped to ${coldTemp.toFixed(1)}°C (Limit: 2.0°C). Risk of freezing damage!`;
    } else if (coldDoorOpen) {
      alertType = "door_open";
      alertTitle = "🚪 Cold Door Left Open!";
      alertMsg = `Cold storage door is OPEN on unit ${device.device_name || "MediGuard"}. Close immediately!`;
      severity = "warning";
    } else if (isSensorFault) {
      alertType = "sensor_fault";
      alertTitle = "⚠️ Sensor Hardware Error!";
      alertMsg = `Hardware telemetry reports sensor failure on ${device.device_name || "MediGuard"}. Check unit connection.`;
      severity = "critical";
    } else if (normalTemp > 25.0 || normalTemp < 15.0) {
      alertType = "normal_temp_abnormal";
      alertTitle = "⚠️ Room Compartment Out of Range";
      alertMsg = `Room temperature is ${normalTemp.toFixed(1)}°C (Safe: 15-25°C).`;
      severity = "warning";
    }

    // Check Cooldown: Avoid duplicate push if an active alert of this type was dispatched within the last 3 minutes
    const threeMinutesAgo = new Date(Date.now() - 3 * 60 * 1000).toISOString();
    const { data: existingAlert } = await supabase
      .from("alerts")
      .select("id")
      .eq("user_id", device.user_id)
      .eq("type", alertType)
      .gte("created_at", threeMinutesAgo)
      .maybeSingle();

    if (!existingAlert) {
      // 1. Insert alert in database
      await supabase.from("alerts").insert({
        user_id: device.user_id,
        device_id: device.id,
        type: alertType,
        title: alertTitle,
        message: alertMsg,
        severity: severity,
        status: "active",
        data_source: dataSource,
        created_at: new Date().toISOString(),
      });

      // 2. Dispatch push notification via OneSignal
      EdgeRuntime.waitUntil(
        sendOneSignalPush(device.user_id, alertTitle, alertMsg, {
          alert_type: alertType,
          device_id: device.id,
          cold_temp: coldTemp,
          normal_temp: normalTemp,
        })
      );
    }
  }

  return new Response(
    JSON.stringify({
      success: true,
      reading_id: inserted.id,
      device_id: device.id,
      serial_number: device.serial_number,
      recorded_at: inserted.recorded_at,
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
