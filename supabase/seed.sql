-- MediGuard Seed Data (Optional Test Fixtures)
-- Note: Replace '<YOUR_AUTH_USER_UUID>' with a real user UID after creating an account via Supabase Auth.
-- All seed items are clearly identified with notes and demo tags.

DO $$
DECLARE
    v_user_id UUID;
    v_device_id UUID;
    v_med_insulin UUID := gen_random_uuid();
    v_med_amox UUID := gen_random_uuid();
    v_med_eye UUID := gen_random_uuid();
    v_med_paracetamol UUID := gen_random_uuid();
BEGIN
    -- Look for the first authenticated user in auth.users, or exit if none exists
    SELECT id INTO v_user_id FROM auth.users ORDER BY created_at ASC LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'No user found in auth.users. Please create an account in the app first, then run seed.';
        RETURN;
    END IF;

    -- Create or fetch default device
    INSERT INTO public.devices (id, user_id, device_name, model_version, is_online, data_source)
    VALUES (gen_random_uuid(), v_user_id, 'MediGuard Smart Box #01', 'ESP32-MediGuard-v1', true, 'simulated')
    RETURNING id INTO v_device_id;

    -- Device settings
    INSERT INTO public.device_settings (
        user_id, device_id,
        normal_temp_min_c, normal_temp_max_c,
        normal_humidity_min_pct, normal_humidity_max_pct,
        cold_temp_min_c, cold_temp_max_c,
        cold_humidity_min_pct, cold_humidity_max_pct,
        door_open_warning_seconds
    )
    VALUES (
        v_user_id, v_device_id,
        15.0, 25.0,
        30.0, 60.0,
        2.0, 8.0,
        35.0, 65.0,
        60
    )
    ON CONFLICT (user_id) DO NOTHING;

    -- Insert Sample Medicines
    -- 1. Insulin Glargine (Refrigerated)
    INSERT INTO public.medicines (
        id, user_id, device_id, name, brand, strength, dosage_form, batch_number,
        expiry_date, rfid_uid, required_storage,
        min_temperature_c, max_temperature_c, min_humidity_pct, max_humidity_pct,
        quantity, compartment, status, notes
    ) VALUES (
        v_med_insulin, v_user_id, v_device_id,
        'Insulin Glargine', 'Lantus SoloStar', '100 units/mL', 'Injectable pen', 'BAT-2026-091',
        CURRENT_DATE + INTERVAL '180 days', 'E28011700000020', 'cold',
        2.0, 8.0, 30.0, 70.0,
        5, 'cold', 'stored', '[DEMO SEED] Keep refrigerated at 2-8°C. Do not freeze.'
    );

    -- 2. Amoxicillin & Clavulanate (Refrigerated suspension once reconstituted)
    INSERT INTO public.medicines (
        id, user_id, device_id, name, brand, strength, dosage_form, batch_number,
        expiry_date, rfid_uid, required_storage,
        min_temperature_c, max_temperature_c, min_humidity_pct, max_humidity_pct,
        quantity, compartment, status, notes
    ) VALUES (
        v_med_amox, v_user_id, v_device_id,
        'Amoxicillin Clavulanate', 'Augmentin ES', '600mg/42.9mg/5mL', 'Oral Suspension', 'AUG-7821',
        CURRENT_DATE + INTERVAL '10 days', 'E28011700000021', 'cold',
        2.0, 8.0, 30.0, 70.0,
        2, 'cold', 'stored', '[DEMO SEED] Reconstituted oral suspension. Expiry nearing in 10 days.'
    );

    -- 3. Latanoprost Eye Drops (Cold Storage)
    INSERT INTO public.medicines (
        id, user_id, device_id, name, brand, strength, dosage_form, batch_number,
        expiry_date, rfid_uid, required_storage,
        min_temperature_c, max_temperature_c, min_humidity_pct, max_humidity_pct,
        quantity, compartment, status, notes
    ) VALUES (
        v_med_eye, v_user_id, v_device_id,
        'Latanoprost Eye Drops', 'Xalatan', '0.005%', 'Ophthalmic Solution', 'XAL-4402',
        CURRENT_DATE + INTERVAL '365 days', 'E28011700000022', 'cold',
        2.0, 8.0, 30.0, 70.0,
        3, 'cold', 'stored', '[DEMO SEED] Protect from light and keep cold.'
    );

    -- 4. Paracetamol (Normal Room Storage)
    INSERT INTO public.medicines (
        id, user_id, device_id, name, brand, strength, dosage_form, batch_number,
        expiry_date, rfid_uid, required_storage,
        min_temperature_c, max_temperature_c, min_humidity_pct, max_humidity_pct,
        quantity, compartment, status, notes
    ) VALUES (
        v_med_paracetamol, v_user_id, v_device_id,
        'Paracetamol Tablets', 'Panadol Extra', '500mg/65mg', 'Tablet', 'PAN-9912',
        CURRENT_DATE + INTERVAL '720 days', 'E28011700000023', 'normal',
        15.0, 25.0, 30.0, 60.0,
        20, 'normal', 'stored', '[DEMO SEED] Store below 25°C in a dry place.'
    );

    -- Sample Alerts
    INSERT INTO public.alerts (
        user_id, device_id, medicine_id, type, title, message, severity, status, data_source
    ) VALUES (
        v_user_id, v_device_id, v_med_amox, 'medicine_nearing_expiry',
        'Medicine Nearing Expiry: Augmentin ES',
        'Augmentin ES batch AUG-7821 expires in 10 days. Check prescription schedule.',
        'warning', 'active', 'simulated'
    );

    -- Sample Historical Sensor Readings (Last 2 hours)
    INSERT INTO public.sensor_readings (
        device_id, user_id, normal_temperature_c, normal_humidity_pct,
        cold_temperature_c, cold_humidity_pct,
        normal_light_detected, cold_light_detected,
        normal_door_open, cold_door_open,
        cooling_active, normal_fan_active,
        sensor_health, data_source, recorded_at
    )
    SELECT
        v_device_id,
        v_user_id,
        21.5 + (random() * 1.5 - 0.75),
        48.0 + (random() * 4.0 - 2.0),
        4.2 + (random() * 1.2 - 0.6),
        52.0 + (random() * 3.0 - 1.5),
        false, false, false, false,
        true, true,
        'healthy', 'simulated',
        NOW() - (n || ' minutes')::INTERVAL
    FROM generate_series(0, 120, 5) AS n;

    -- Sample Inventory Transactions
    INSERT INTO public.inventory_transactions (
        user_id, medicine_id, device_id, action, quantity_change, compartment, rfid_uid, initiation_method, confirmation_method, status, initiated_at, confirmed_at, notes
    ) VALUES (
        v_user_id, v_med_insulin, v_device_id, 'add', 5, 'cold', 'E28011700000020', 'rfid', 'app', 'confirmed', NOW() - INTERVAL '2 days', NOW() - INTERVAL '2 days' + INTERVAL '12 seconds', '[DEMO SEED] Initial stock entry'
    ), (
        v_user_id, v_med_paracetamol, v_device_id, 'add', 20, 'normal', 'E28011700000023', 'manual', 'app', 'confirmed', NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day' + INTERVAL '15 seconds', '[DEMO SEED] Restocked'
    );

    RAISE NOTICE 'Demo seed data inserted successfully for user %', v_user_id;
END $$;
