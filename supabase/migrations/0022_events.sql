-- 0022_events.sql — Event log for analytics + crash reports. Run AFTER 0021.
--
-- There was no visibility at all: if the app crashed on a player's phone, or
-- everyone abandoned before their first capture, we'd never know. This gives
-- a funnel and a crash log without adding a third-party SDK.
--
-- Runs are also logged with their GPS diagnostics (accuracy, fixes used vs
-- seen, why samples were rejected) so real-world capture failures can be
-- diagnosed from the data instead of asking the player for screenshots.

create table if not exists app_events (
  id         bigserial primary key,
  player_id  uuid references players (id) on delete set null,
  name       text not null,
  props      jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists app_events_name_time_idx on app_events (name, created_at desc);
create index if not exists app_events_player_idx    on app_events (player_id, created_at desc);

alter table app_events enable row level security;
-- Players may read their own events; nobody writes directly (see log_event).
create policy "events readable by owner" on app_events
  for select using (auth.uid() = player_id);

-- ── log_event: the only way to write an event ───────────────────────────────
-- SECURITY DEFINER keeps app_events consistent with the rest of the schema:
-- clients never write tables directly (0019). Stamps the player itself so an
-- event can't be attributed to someone else.
create or replace function log_event(event_name text, event_props jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  if length(coalesce(event_name, '')) = 0 then return; end if;
  -- Anonymous (pre-sign-in) events are allowed with a null player.
  insert into app_events (player_id, name, props)
  values (auth.uid(), left(event_name, 60), coalesce(event_props, '{}'::jsonb));
end;
$$;

-- ── funnel: how far players get, per day ────────────────────────────────────
-- Answers the question that matters most right now: do people who start a run
-- ever successfully claim anything?
create or replace function event_funnel(days int default 7)
returns table (day date, event text, count bigint)
language sql stable security definer set search_path = public as $$
  select created_at::date as day, name as event, count(*)
  from app_events
  where created_at >= current_date - days
  group by 1, 2
  order by 1 desc, 3 desc;
$$;
