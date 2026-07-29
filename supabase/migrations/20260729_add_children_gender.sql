-- Boy/Girl option on child profiles.
alter table public.children
  add column if not exists gender text
  check (gender is null or gender in ('Boy', 'Girl'));
