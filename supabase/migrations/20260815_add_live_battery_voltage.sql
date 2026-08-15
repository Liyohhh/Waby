-- Firmware sendLiveUpdate() includes battery_voltage. PostgREST rejects
-- unknown columns (HTTP 400), which blocks the whole live PATCH.
alter table public.live
  add column if not exists battery_voltage numeric;
