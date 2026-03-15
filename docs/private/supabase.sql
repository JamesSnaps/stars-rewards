-- ═════════════════════════════════════════════════════
-- STAR BANK — Full Supabase Schema
-- Run this in order on a fresh project to set everything
-- up from scratch. Safe to re-run with DROP IF EXISTS.
-- ═════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────
-- DROP EXISTING TABLES (clean slate)
-- ─────────────────────────────────────────────────────
drop table if exists cooldown_tokens   cascade;
drop table if exists reward_requests   cascade;
drop table if exists unlocked_avatars  cascade;
drop table if exists avatars           cascade;
drop table if exists self_claims       cascade;
drop table if exists time_windows      cascade;
drop table if exists history           cascade;
drop table if exists rewards           cascade;
drop table if exists behaviours        cascade;
drop table if exists child_state       cascade;
drop table if exists profiles          cascade;


-- ─────────────────────────────────────────────────────
-- PROFILES
-- One row per child. Parent auth is handled in config.js.
-- ─────────────────────────────────────────────────────
create table profiles (
  id          bigint generated always as identity primary key,
  name        text not null,
  avatar      text not null default '⭐',   -- emoji or base64 image data URL
  color       text not null default '#006CB7',
  created_at  timestamptz not null default now()
);


-- ─────────────────────────────────────────────────────
-- CHILD STATE
-- One row per profile — holds the current star balance.
-- ─────────────────────────────────────────────────────
create table child_state (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  balance     integer not null default 0
);


-- ─────────────────────────────────────────────────────
-- BEHAVIOURS
-- Earn actions, scoped per profile.
-- type: 'parent' | 'self' | 'bonus'
-- ─────────────────────────────────────────────────────
create table behaviours (
  id           bigint generated always as identity primary key,
  profile_id   bigint not null references profiles(id) on delete cascade,
  emoji        text not null default '⭐',
  description  text not null,
  worth        integer not null default 1,
  type         text not null check (type in ('parent', 'self', 'bonus')),
  created_at   timestamptz not null default now()
);


-- ─────────────────────────────────────────────────────
-- REWARDS
-- Things Louis can spend stars on.
-- one_time: if true, disappears after being claimed once.
-- claimed:  set to true when a one_time reward is redeemed.
-- ─────────────────────────────────────────────────────
create table rewards (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  emoji       text not null default '🎁',
  name        text not null,
  cost        integer not null,
  image_url   text,
  one_time    boolean not null default false,
  claimed     boolean not null default false,
  created_at  timestamptz not null default now()
);


-- ─────────────────────────────────────────────────────
-- REWARD REQUESTS
-- A child requests a reward, stars are deducted immediately,
-- and a parent later approves or declines the request.
-- Declined requests should refund the stars in history.
-- ─────────────────────────────────────────────────────
create table reward_requests (
  id           bigint generated always as identity primary key,
  profile_id   bigint not null references profiles(id) on delete cascade,
  reward_id    bigint not null references rewards(id) on delete cascade,
  reward_name  text not null,
  cost         integer not null,
  status       text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz
);


-- ─────────────────────────────────────────────────────
-- HISTORY
-- Transaction log — every earn and spend event.
-- ─────────────────────────────────────────────────────
create table history (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  description text not null,
  amount      integer not null,
  type        text not null check (type in ('earn', 'spend')),
  created_at  timestamptz not null default now()
);


-- ─────────────────────────────────────────────────────
-- TIME WINDOWS
-- Configurable earn windows per profile.
-- Self-claim behaviours are only available within these.
-- e.g. Morning 06:00–10:00, Afternoon 16:00–22:00
-- ─────────────────────────────────────────────────────
create table time_windows (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  label       text not null,
  start_hour  integer not null,
  end_hour    integer not null
);


-- ─────────────────────────────────────────────────────
-- SELF CLAIMS
-- Tracks one self-claim per behaviour per time window.
-- Prevents claiming the same behaviour twice in one window.
-- window_key format: "YYYY-MM-DD-windowlabel" e.g. "2024-03-04-morning"
-- ─────────────────────────────────────────────────────
create table self_claims (
  id            bigint generated always as identity primary key,
  profile_id    bigint not null references profiles(id) on delete cascade,
  behaviour_id  bigint not null references behaviours(id) on delete cascade,
  window_key    text not null,
  created_at    timestamptz not null default now(),
  unique (profile_id, behaviour_id, window_key)
);


-- ─────────────────────────────────────────────────────
-- AVATARS
-- Unlockable profile pictures, defined per profile by parent.
-- tier: 'common' | 'rare' | 'legendary'
-- ─────────────────────────────────────────────────────
create table avatars (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  name        text not null,
  image_url   text not null,
  cost        integer not null default 10,
  tier        text not null default 'common' check (tier in ('common', 'rare', 'legendary')),
  created_at  timestamptz not null default now()
);


-- ─────────────────────────────────────────────────────
-- UNLOCKED AVATARS
-- Tracks which avatars a profile has permanently unlocked.
-- ─────────────────────────────────────────────────────
create table unlocked_avatars (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  avatar_id   bigint not null references avatars(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (profile_id, avatar_id)
);


-- ─────────────────────────────────────────────────────
-- COOLDOWN TOKENS
-- One active token per profile maximum.
-- Freezes self-claims and reward spending for 30 minutes.
-- Parent can clear early by deleting the row.
-- ─────────────────────────────────────────────────────
create table cooldown_tokens (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  reason      text not null,
  issued_at   timestamptz not null default now(),
  expires_at  timestamptz not null default (now() + interval '30 minutes'),
  unique (profile_id)
);


-- ─────────────────────────────────────────────────────
-- BONUS TOKENS
-- One active bonus per profile maximum.
-- Multiplies earned task stars for a limited time.
-- Parent can clear early by deleting the row.
-- ─────────────────────────────────────────────────────
create table bonus_tokens (
  id          bigint generated always as identity primary key,
  profile_id  bigint not null references profiles(id) on delete cascade,
  multiplier  integer not null check (multiplier >= 1),
  issued_at   timestamptz not null default now(),
  expires_at  timestamptz not null,
  unique (profile_id)
);


-- ─────────────────────────────────────────────────────
-- ROW LEVEL SECURITY
-- Open policies — this is a private family app using
-- the anon key. RLS is enabled to satisfy Supabase
-- requirements; policies allow all operations.
-- ─────────────────────────────────────────────────────
alter table profiles          enable row level security;
alter table child_state       enable row level security;
alter table behaviours        enable row level security;
alter table rewards           enable row level security;
alter table reward_requests   enable row level security;
alter table history           enable row level security;
alter table time_windows      enable row level security;
alter table self_claims       enable row level security;
alter table avatars           enable row level security;
alter table unlocked_avatars  enable row level security;
alter table cooldown_tokens   enable row level security;
alter table bonus_tokens      enable row level security;

create policy "allow all" on profiles          for all using (true) with check (true);
create policy "allow all" on child_state       for all using (true) with check (true);
create policy "allow all" on behaviours        for all using (true) with check (true);
create policy "allow all" on rewards           for all using (true) with check (true);
create policy "allow all" on reward_requests   for all using (true) with check (true);
create policy "allow all" on history           for all using (true) with check (true);
create policy "allow all" on time_windows      for all using (true) with check (true);
create policy "allow all" on self_claims       for all using (true) with check (true);
create policy "allow all" on avatars           for all using (true) with check (true);
create policy "allow all" on unlocked_avatars  for all using (true) with check (true);
create policy "allow all" on cooldown_tokens   for all using (true) with check (true);
create policy "allow all" on bonus_tokens      for all using (true) with check (true);


-- ─────────────────────────────────────────────────────
-- SEED — Louis's profile
-- ─────────────────────────────────────────────────────
insert into profiles (name, avatar, color)
values ('Louis', '⭐', '#006CB7');

-- Note: profile id will be 1 if this is a fresh project.
-- Confirm with: select id from profiles where name = 'Louis';

insert into child_state (profile_id, balance)
values (1, 0);

insert into time_windows (profile_id, label, start_hour, end_hour) values
  (1, 'Morning',   6,  10),
  (1, 'Afternoon', 16, 22);

insert into behaviours (profile_id, emoji, description, worth, type) values
  (1, '😌', 'Handled a "no" calmly',            2, 'parent'),
  (1, '💬', 'Used kind words when frustrated',   2, 'parent'),
  (1, '🤝', 'Apologised genuinely',              2, 'parent'),
  (1, '⏳', 'Showed patience',                   2, 'parent'),
  (1, '👂', 'Responded first time when asked',   2, 'parent'),
  (1, '💛', 'Was kind unprompted',               2, 'parent'),
  (1, '🧘', 'Calmed himself down after upset',   2, 'parent'),
  (1, '👕', 'Got dressed without being asked',   1, 'self'),
  (1, '🦷', 'Cleaned teeth without reminders',   1, 'self'),
  (1, '🧹', 'Tidied room / put toys away',       1, 'self'),
  (1, '🎒', 'Put bag & shoes away',              1, 'self'),
  (1, '🍽️','Ate dinner without complaining',    1, 'self'),
  (1, '🛏️','Got into bed on time',              1, 'self'),
  (1, '🌟', 'Bonus star — something amazing!',   3, 'bonus');

insert into rewards (profile_id, emoji, name, cost, one_time) values
  (1, '🕹️', 'Extra 30 mins screen time', 4,  false),
  (1, '🍕',  'Choice of dinner',          5,  false),
  (1, '🛁',  'Mega bubble bath with toys',6,  false),
  (1, '🎬',  'Movie night',               8,  false),
  (1, '💛',  'Day out with Mummy',        20, true),
  (1, '🧱',  'Small Lego set',            30, true),
  (1, '🏆',  'Big Lego set',              60, true);
