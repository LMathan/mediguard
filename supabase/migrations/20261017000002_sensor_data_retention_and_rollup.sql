-- Migration: 20261017000002_sensor_data_retention_and_rollup.sql
-- Description: Automated aggregation rollups and 7-day data retention cleanup for ESP32 telemetry

-- 1. Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Create Rollup Table for long-term compliance storage
CREATE TABLE IF NOT EXISTS public.sensor_hourly_rollups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
    bucket_start TIMESTAMPTZ NOT NULL,
    sample_count INTEGER NOT NULL,
    
    -- Normal Compartment Aggregations
    normal_temp_avg DOUBLE PRECISION,
    normal_temp_min DOUBLE PRECISION,
    normal_temp_max DOUBLE PRECISION,
    normal_humidity_avg DOUBLE PRECISION,
    normal_humidity_min DOUBLE PRECISION,
    normal_humidity_max DOUBLE PRECISION,
    
    -- Cold Storage Aggregations
    cold_temp_avg DOUBLE PRECISION,
    cold_temp_min DOUBLE PRECISION,
    cold_temp_max DOUBLE PRECISION,
    cold_humidity_avg DOUBLE PRECISION,
    cold_humidity_min DOUBLE PRECISION,
    cold_humidity_max DOUBLE PRECISION,
    
    -- Discrete Event Counters
    normal_door_open_samples INTEGER DEFAULT 0,
    cold_door_open_samples INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_device_hourly_bucket UNIQUE (device_id, bucket_start)
);

-- Enable RLS on rollups
ALTER TABLE public.sensor_hourly_rollups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read rollups"
    ON public.sensor_hourly_rollups FOR SELECT
    TO authenticated
    USING (true);

CREATE INDEX IF NOT EXISTS idx_sensor_rollups_device_bucket 
    ON public.sensor_hourly_rollups(device_id, bucket_start DESC);

-- 3. Automated Hourly Rollup Aggregation Function
CREATE OR REPLACE FUNCTION public.rollup_sensor_readings()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.sensor_hourly_rollups (
        device_id,
        bucket_start,
        sample_count,
        normal_temp_avg, normal_temp_min, normal_temp_max,
        normal_humidity_avg, normal_humidity_min, normal_humidity_max,
        cold_temp_avg, cold_temp_min, cold_temp_max,
        cold_humidity_avg, cold_humidity_min, cold_humidity_max,
        normal_door_open_samples, cold_door_open_samples
    )
    SELECT
        device_id,
        date_trunc('hour', recorded_at) AS bucket_start,
        COUNT(*)::INTEGER,
        ROUND(AVG(normal_temperature_c)::numeric, 2),
        MIN(normal_temperature_c),
        MAX(normal_temperature_c),
        ROUND(AVG(normal_humidity_pct)::numeric, 2),
        MIN(normal_humidity_pct),
        MAX(normal_humidity_pct),
        ROUND(AVG(cold_temperature_c)::numeric, 2),
        MIN(cold_temperature_c),
        MAX(cold_temperature_c),
        ROUND(AVG(cold_humidity_pct)::numeric, 2),
        MIN(cold_humidity_pct),
        MAX(cold_humidity_pct),
        COUNT(*) FILTER (WHERE normal_door_open = true)::INTEGER,
        COUNT(*) FILTER (WHERE cold_door_open = true)::INTEGER
    FROM public.sensor_readings
    WHERE recorded_at >= NOW() - INTERVAL '3 hours'
      AND recorded_at < date_trunc('hour', NOW())
    GROUP BY device_id, date_trunc('hour', recorded_at)
    ON CONFLICT (device_id, bucket_start) DO UPDATE
    SET sample_count = EXCLUDED.sample_count,
        normal_temp_avg = EXCLUDED.normal_temp_avg,
        normal_temp_min = EXCLUDED.normal_temp_min,
        normal_temp_max = EXCLUDED.normal_temp_max,
        normal_humidity_avg = EXCLUDED.normal_humidity_avg,
        normal_humidity_min = EXCLUDED.normal_humidity_min,
        normal_humidity_max = EXCLUDED.normal_humidity_max,
        cold_temp_avg = EXCLUDED.cold_temp_avg,
        cold_temp_min = EXCLUDED.cold_temp_min,
        cold_temp_max = EXCLUDED.cold_temp_max,
        cold_humidity_avg = EXCLUDED.cold_humidity_avg,
        cold_humidity_min = EXCLUDED.cold_humidity_min,
        cold_humidity_max = EXCLUDED.cold_humidity_max,
        normal_door_open_samples = EXCLUDED.normal_door_open_samples,
        cold_door_open_samples = EXCLUDED.cold_door_open_samples;
END;
$$;

-- 4. Automated Raw Data Purge Function
CREATE OR REPLACE FUNCTION public.cleanup_old_sensor_readings(
    retention_days INTEGER DEFAULT 7
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_rows INTEGER := 0;
BEGIN
    -- Ensure recent completed hours are aggregated before pruning raw data
    PERFORM public.rollup_sensor_readings();

    -- Delete expired raw readings in chunks to avoid table locks
    WITH to_delete AS (
        SELECT id FROM public.sensor_readings
        WHERE recorded_at < NOW() - (retention_days || ' days')::INTERVAL
        LIMIT 5000
    )
    DELETE FROM public.sensor_readings
    WHERE id IN (SELECT id FROM to_delete);
    
    GET DIAGNOSTICS deleted_rows = ROW_COUNT;
    RETURN deleted_rows;
END;
$$;

-- 5. Scheduled Jobs Configuration
SELECT cron.schedule(
    'sensor-hourly-rollup',
    '5 * * * *',
    'SELECT public.rollup_sensor_readings();'
);

SELECT cron.schedule(
    'sensor-daily-cleanup',
    '30 2 * * *',
    'SELECT public.cleanup_old_sensor_readings(7);'
);
