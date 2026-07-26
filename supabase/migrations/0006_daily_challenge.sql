-- 0006_daily_challenge.sql — Phase 8 layer 2: a shared daily challenge.
-- Run AFTER 0005. The challenge is deterministic by date (everyone gets the
-- same one each day). Progress is derived from the append-only `runs` log, so
-- it stays correct even when turf is later stolen.

create or replace function challenge_status()
returns table (metric text, target numeric, label text, progress numeric, completed boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  d  int := (extract(epoch from current_date) / 86400)::int % 3;
  m  text;
  tg numeric;
  lb text;
  pg numeric;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  -- Pick today's challenge deterministically from the date.
  if d = 0 then
    m := 'area';     tg := 3000; lb := 'Claim 3,000 m² of turf today';
  elsif d = 1 then
    m := 'loops';    tg := 3;    lb := 'Close 3 loops today';
  else
    m := 'distance'; tg := 2000; lb := 'Walk 2 km during runs today';
  end if;

  -- Progress from today's runs (append-only, unaffected by stealing).
  if m = 'area' then
    select coalesce(sum(area_gained), 0) into pg
      from runs where player_id = auth.uid() and started_at::date = current_date;
  elsif m = 'loops' then
    select count(*) into pg
      from runs where player_id = auth.uid() and started_at::date = current_date;
  else
    select coalesce(sum(distance), 0) into pg
      from runs where player_id = auth.uid() and started_at::date = current_date;
  end if;

  return query select m, tg, lb, pg, pg >= tg;
end;
$$;
