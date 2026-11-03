-- ==============================================================================
-- KITH - Centralized IPO Ingestion Schedule via pg_cron & pg_net
-- ==============================================================================
-- Executes inside Supabase PostgreSQL.
-- Triggers the Edge Function 'ipo-data' twice daily on Indian stock market trading days:
--   1. 10:00 AM IST (04:30 AM UTC) - Market Open
--   2. 05:00 PM IST (11:30 AM UTC) - Market Close
--
-- Prerequisites:
-- 1. Enable 'pg_cron' and 'pg_net' in Supabase Dashboard -> Database -> Extensions.
-- 2. Store your CRON_SECRET into Supabase Secrets or pass via the curl payload.
-- ==============================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Unschedule any previous jobs
SELECT cron.unschedule('kith-ipo-sync-market-open') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'kith-ipo-sync-market-open'
);
SELECT cron.unschedule('kith-ipo-sync-market-close') WHERE EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'kith-ipo-sync-market-close'
);

-- Note: Replace YOUR_PROJECT_REF and YOUR_CRON_SECRET with actual values.
-- Job 1: Market Open at 04:30 UTC (10:00 AM IST) Monday through Friday
SELECT cron.schedule(
    'kith-ipo-sync-market-open',
    '30 4 * * 1-5',
    $$
    SELECT net.http_post(
        url := 'https://' || current_setting('app.settings.supabase_project_ref', true) || '.supabase.co/functions/v1/ipo-data?sync=true',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret', true)
        ),
        body := '{}'::jsonb
    );
    $$
);

-- Job 2: Market Close at 11:30 UTC (05:00 PM IST) Monday through Friday
SELECT cron.schedule(
    'kith-ipo-sync-market-close',
    '30 11 * * 1-5',
    $$
    SELECT net.http_post(
        url := 'https://' || current_setting('app.settings.supabase_project_ref', true) || '.supabase.co/functions/v1/ipo-data?sync=true',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret', true)
        ),
        body := '{}'::jsonb
    );
    $$
);
