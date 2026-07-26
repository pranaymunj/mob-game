-- 0005_homebase_streaks.sql — Phase 8 layer 1: Home Base + daily streaks.
-- Run AFTER 0004. Home base is stored block-level approximate (never an exact
-- address) per the privacy rules (CLAUDE.md Part 5).

alter table players
  add column if not exists home_lng      double precision,
  add column if not exists home_lat      double precision,
  add column if not exists current_streak int  not null default 0,
  add column if not exists longest_streak int  not null default 0,
  add column if not exists last_played_at date;

-- ── set_home_base: snap to ~block level (3 decimals ≈ 110 m) for privacy ──────
create or replace function set_home_base(lng double precision, lat double precision)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  update players
     set home_lng = round(lng::numeric, 3),
         home_lat = round(lat::numeric, 3)
   where id = auth.uid();
end;
$$;

-- ── record_activity: bump the daily streak when the player is active ──────────
-- Same day → no change. Yesterday → +1. Any older / first time → reset to 1.
create or replace function record_activity()
returns table (current_streak int, longest_streak int)
language plpgsql security definer set search_path = public as $$
declare
  today date := current_date;
  last  date;
  cur   int;
  best  int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select p.last_played_at, p.current_streak, p.longest_streak
    into last, cur, best
    from players p where p.id = auth.uid();

  if last = today then
    -- already counted today, leave as is
    null;
  elsif last = today - 1 then
    cur := cur + 1;
  else
    cur := 1;
  end if;

  best := greatest(coalesce(best, 0), cur);

  update players
     set current_streak = cur,
         longest_streak = best,
         last_played_at = today
   where id = auth.uid();

  return query select cur, best;
end;
$$;
