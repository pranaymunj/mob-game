-- 0010_ghost_runs.sql — Phase 8 layer 6: ghost runs (replay your best route).
-- Run AFTER 0009. Stores each player's best (longest-distance) run path so it
-- can be replayed on the map. Path is a JSON array of [lng, lat] points.

create table if not exists ghost_runs (
  player_id  uuid primary key references players (id) on delete cascade,
  path       jsonb   not null,
  distance   numeric not null default 0,
  created_at timestamptz not null default now()
);

alter table ghost_runs enable row level security;
create policy "ghost readable by owner" on ghost_runs for select using (auth.uid() = player_id);

-- ── save_ghost_run: keep it only if it beats the stored best ──────────────────
create or replace function save_ghost_run(run_path jsonb, dist numeric)
returns void language plpgsql security definer set search_path = public as $$
declare best numeric;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  select distance into best from ghost_runs where player_id = auth.uid();
  if best is null or dist > best then
    insert into ghost_runs (player_id, path, distance)
    values (auth.uid(), run_path, dist)
    on conflict (player_id) do update set path = excluded.path,
                                          distance = excluded.distance,
                                          created_at = now();
  end if;
end;
$$;
