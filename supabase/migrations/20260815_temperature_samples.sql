-- 12-hour seat temperature history for Family → Children analytics.
-- `live` is a single overwriting row, so DHT readings must be sampled here.
--
-- Run this in the Supabase SQL editor (project pvafygrloelptlmnhfog) if the
-- CLI is not linked. Firmware is unchanged: ESP32 still PATCHes `live` only.

create table if not exists public.temperature_samples (
  id uuid primary key default gen_random_uuid(),
  recorded_at timestamptz not null default now(),
  temperature numeric not null
);

create index if not exists temperature_samples_recorded_at_idx
  on public.temperature_samples (recorded_at desc);

alter table public.temperature_samples enable row level security;

drop policy if exists "authenticated_select_temperature_samples"
  on public.temperature_samples;
create policy "authenticated_select_temperature_samples"
  on public.temperature_samples
  for select
  to authenticated
  using (true);

drop policy if exists "authenticated_insert_temperature_samples"
  on public.temperature_samples;
create policy "authenticated_insert_temperature_samples"
  on public.temperature_samples
  for insert
  to authenticated
  with check (true);

grant select, insert on table public.temperature_samples to authenticated;

-- Sample at most once per minute on live temperature writes (ESP32 ~1 Hz).
create or replace function public.log_live_temperature()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.temperature is null or NEW.temperature <= 0 then
    return NEW;
  end if;

  if exists (
    select 1
    from public.temperature_samples
    where recorded_at > now() - interval '1 minute'
  ) then
    return NEW;
  end if;

  insert into public.temperature_samples (temperature, recorded_at)
  values (NEW.temperature, now());

  delete from public.temperature_samples
  where recorded_at < now() - interval '13 hours';

  return NEW;
end;
$$;

drop trigger if exists trg_log_live_temperature on public.live;
create trigger trg_log_live_temperature
  after insert or update of temperature on public.live
  for each row
  execute procedure public.log_live_temperature();
