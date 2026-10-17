-- MediGuard Database Schema Migration
-- Version: 20261017000001
-- Description: Core schema, tables, constraints, functions, RLS policies, and triggers for MediGuard

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Trigger to auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, avatar_url)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'MediGuard User'),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO UPDATE
    SET full_name = EXCLUDED.full_name;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. DEVICES TABLE
CREATE TABLE IF NOT EXISTS public.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_name TEXT NOT NULL DEFAULT 'MediGuard Box Alpha',
    model_version TEXT NOT NULL DEFAULT 'ESP32-MediGuard-v1',
    serial_number TEXT,
    is_online BOOLEAN NOT NULL DEFAULT true,
    data_source TEXT NOT NULL DEFAULT 'simulated', -- 'simulated' | 'hardware'
    last_seen_at TIMESTAMPTZ DEFAULT TIMEZONE('utc'::text, NOW()),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own devices"
    ON public.devices FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. DEVICE SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.device_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    device_id UUID REFERENCES public.devices(id) ON DELETE CASCADE,
    normal_temp_min_c DOUBLE PRECISION NOT NULL DEFAULT 15.0,
    normal_temp_max_c DOUBLE PRECISION NOT NULL DEFAULT 25.0,
    normal_humidity_min_pct DOUBLE PRECISION NOT NULL DEFAULT 30.0,
    normal_humidity_max_pct DOUBLE PRECISION NOT NULL DEFAULT 60.0,
    cold_temp_min_c DOUBLE PRECISION NOT NULL DEFAULT 2.0,
    cold_temp_max_c DOUBLE PRECISION NOT NULL DEFAULT 8.0,
    cold_humidity_min_pct DOUBLE PRECISION NOT NULL DEFAULT 35.0,
    cold_humidity_max_pct DOUBLE PRECISION NOT NULL DEFAULT 65.0,
    door_open_warning_seconds INTEGER NOT NULL DEFAULT 60,
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    critical_alert_vibrate BOOLEAN NOT NULL DEFAULT true,
    expiry_warning_days INTEGER NOT NULL DEFAULT 30,
    simulation_interval_seconds INTEGER NOT NULL DEFAULT 3,
    persist_interval_seconds INTEGER NOT NULL DEFAULT 30,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE public.device_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own device settings"
    ON public.device_settings FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 4. MEDICINES TABLE
CREATE TABLE IF NOT EXISTS public.medicines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    brand TEXT,
    strength TEXT,
    dosage_form TEXT,
    batch_number TEXT,
    expiry_date DATE NOT NULL,
    rfid_uid TEXT,
    required_storage TEXT NOT NULL DEFAULT 'normal', -- 'normal' | 'cold' | 'custom'
    min_temperature_c DOUBLE PRECISION,
    max_temperature_c DOUBLE PRECISION,
    min_humidity_pct DOUBLE PRECISION,
    max_humidity_pct DOUBLE PRECISION,
    quantity INTEGER NOT NULL DEFAULT 1,
    compartment TEXT NOT NULL DEFAULT 'normal', -- 'normal' | 'cold'
    status TEXT NOT NULL DEFAULT 'stored', -- 'outside' | 'pending_add' | 'stored' | 'pending_remove' | 'removed'
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Unique index ensuring a user cannot assign the same RFID UID to multiple active medicines
CREATE UNIQUE INDEX IF NOT EXISTS idx_medicines_user_rfid_unique
    ON public.medicines (user_id, rfid_uid)
    WHERE rfid_uid IS NOT NULL AND status != 'removed';

CREATE INDEX IF NOT EXISTS idx_medicines_user_id ON public.medicines(user_id);
CREATE INDEX IF NOT EXISTS idx_medicines_status ON public.medicines(status);
CREATE INDEX IF NOT EXISTS idx_medicines_expiry_date ON public.medicines(expiry_date);

ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own medicines"
    ON public.medicines FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 5. SENSOR READINGS TABLE
CREATE TABLE IF NOT EXISTS public.sensor_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    normal_temperature_c DOUBLE PRECISION NOT NULL,
    normal_humidity_pct DOUBLE PRECISION NOT NULL,
    cold_temperature_c DOUBLE PRECISION NOT NULL,
    cold_humidity_pct DOUBLE PRECISION NOT NULL,
    normal_light_detected BOOLEAN NOT NULL DEFAULT false,
    cold_light_detected BOOLEAN NOT NULL DEFAULT false,
    normal_door_open BOOLEAN NOT NULL DEFAULT false,
    cold_door_open BOOLEAN NOT NULL DEFAULT false,
    cooling_active BOOLEAN NOT NULL DEFAULT false,
    normal_fan_active BOOLEAN NOT NULL DEFAULT false,
    sensor_health TEXT NOT NULL DEFAULT 'healthy', -- 'healthy' | 'warning' | 'error'
    data_source TEXT NOT NULL DEFAULT 'simulated', -- 'simulated' | 'hardware'
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE INDEX IF NOT EXISTS idx_sensor_readings_device_recorded ON public.sensor_readings(device_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_user_recorded ON public.sensor_readings(user_id, recorded_at DESC);

ALTER TABLE public.sensor_readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own sensor readings"
    ON public.sensor_readings FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 6. INVENTORY TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.inventory_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    medicine_id UUID REFERENCES public.medicines(id) ON DELETE SET NULL,
    device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- 'add' | 'remove' | 'adjust_quantity'
    quantity_change INTEGER NOT NULL,
    compartment TEXT NOT NULL, -- 'normal' | 'cold'
    rfid_uid TEXT,
    initiation_method TEXT NOT NULL DEFAULT 'manual', -- 'rfid' | 'manual'
    confirmation_method TEXT NOT NULL DEFAULT 'app', -- 'app' | 'hardware_button'
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'confirmed' | 'cancelled' | 'failed'
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    confirmed_at TIMESTAMPTZ,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_initiated ON public.inventory_transactions(user_id, initiated_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_medicine ON public.inventory_transactions(medicine_id);

ALTER TABLE public.inventory_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own transactions"
    ON public.inventory_transactions FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 7. ALERTS TABLE
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id UUID REFERENCES public.devices(id) ON DELETE SET NULL,
    medicine_id UUID REFERENCES public.medicines(id) ON DELETE SET NULL,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'info', -- 'info' | 'warning' | 'critical'
    status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'acknowledged' | 'resolved'
    data_source TEXT NOT NULL DEFAULT 'simulated',
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc'::text, NOW()),
    acknowledged_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_alerts_user_status_created ON public.alerts(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_type ON public.alerts(type);

ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own alerts"
    ON public.alerts FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 8. ATOMIC INVENTORY CONFIRMATION FUNCTION
CREATE OR REPLACE FUNCTION public.confirm_inventory_transaction(
    p_transaction_id UUID,
    p_confirm BOOLEAN,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tx RECORD;
    v_med RECORD;
    v_new_quantity INT;
    v_new_status TEXT;
BEGIN
    -- Verify ownership
    SELECT * INTO v_tx
    FROM public.inventory_transactions
    WHERE id = p_transaction_id AND user_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction not found or unauthorized';
    END IF;

    IF v_tx.status != 'pending' THEN
        RAISE EXCEPTION 'Transaction is already %', v_tx.status;
    END IF;

    IF NOT p_confirm THEN
        -- Transaction cancelled
        UPDATE public.inventory_transactions
        SET status = 'cancelled',
            confirmed_at = NOW(),
            notes = COALESCE(p_notes, notes)
        WHERE id = p_transaction_id;

        -- Revert medicine pending status if medicine exists
        IF v_tx.medicine_id IS NOT NULL THEN
            UPDATE public.medicines
            SET status = CASE
                WHEN v_tx.action = 'add' THEN 'outside'
                ELSE 'stored'
            END,
            updated_at = NOW()
            WHERE id = v_tx.medicine_id;
        END IF;

        RETURN jsonb_build_object('success', true, 'status', 'cancelled');
    END IF;

    -- Confirmed: fetch medicine
    SELECT * INTO v_med
    FROM public.medicines
    WHERE id = v_tx.medicine_id AND user_id = auth.uid()
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Associated medicine not found';
    END IF;

    v_new_quantity := v_med.quantity + v_tx.quantity_change;
    IF v_new_quantity < 0 THEN
        v_new_quantity := 0;
    END IF;

    v_new_status := CASE
        WHEN v_tx.action = 'remove' AND v_new_quantity = 0 THEN 'removed'
        WHEN v_tx.action = 'remove' THEN 'stored'
        WHEN v_tx.action = 'add' THEN 'stored'
        ELSE v_med.status
    END;

    UPDATE public.medicines
    SET quantity = v_new_quantity,
        status = v_new_status,
        compartment = v_tx.compartment,
        updated_at = NOW()
    WHERE id = v_med.id;

    UPDATE public.inventory_transactions
    SET status = 'confirmed',
        confirmed_at = NOW(),
        notes = COALESCE(p_notes, notes)
    WHERE id = p_transaction_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'confirmed',
        'medicine_id', v_med.id,
        'new_quantity', v_new_quantity,
        'medicine_status', v_new_status
    );
END;
$$;

-- Grant execution to authenticated users
REVOKE ALL ON FUNCTION public.confirm_inventory_transaction(UUID, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_inventory_transaction(UUID, BOOLEAN, TEXT) TO authenticated;

-- Setup Realtime publications
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.medicines;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.alerts;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.sensor_readings;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.inventory_transactions;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.devices;
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;
