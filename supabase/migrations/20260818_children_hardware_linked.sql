-- First child per family is the physical ESP32 seat (`live` id = 1).
-- Later children in that family are simulated (always SAFE in the app).

alter table public.children
  add column if not exists hardware_linked boolean not null default false;

-- Idempotent: exactly one hardware-linked child per family (earliest created_at).
update public.children
set hardware_linked = false;

update public.children c
set hardware_linked = true
from (
  select distinct on (family_id) id
  from public.children
  where family_id is not null
  order by family_id, created_at asc nulls last, id asc
) firsts
where c.id = firsts.id;

create unique index if not exists children_one_hardware_linked_per_family
  on public.children (family_id)
  where hardware_linked = true;
