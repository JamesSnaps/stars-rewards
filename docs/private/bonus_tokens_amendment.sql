create table if not exists bonus_tokens (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  multiplier  integer not null check (multiplier >= 1),
  issued_at   timestamptz not null default now(),
  expires_at  timestamptz not null,
  unique (profile_id)
);

alter table bonus_tokens enable row level security;

drop policy if exists "allow all" on bonus_tokens;
create policy "allow all" on bonus_tokens for all using (true) with check (true);
