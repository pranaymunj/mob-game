-- 0008_crews.sql — Phase 8 layer 4: crews (teams that pool turf).
-- Run AFTER 0007. Players can create/join/leave a crew; crews rank by the sum
-- of their members' total_area.

create table if not exists crews (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  color      text not null default '#0072B2',
  created_at timestamptz not null default now()
);

alter table players add column if not exists crew_id uuid references crews (id) on delete set null;

alter table crews enable row level security;
create policy "crews readable by all" on crews for select using (true);

-- ── create_crew: make a crew and join it ─────────────────────────────────────
create or replace function create_crew(crew_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
  n int;
  hexes text[] := array['#E69F00','#56B4E9','#009E73','#F0E442','#0072B2','#D55E00','#CC79A7'];
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  if length(trim(crew_name)) < 2 then raise exception 'crew name too short'; end if;

  select count(*) into n from crews;
  insert into crews (name, color) values (trim(crew_name), hexes[(n % 7) + 1])
  returning id into new_id;

  update players set crew_id = new_id where id = auth.uid();
  return new_id;
end;
$$;

-- ── join_crew: join an existing crew by name ─────────────────────────────────
create or replace function join_crew(crew_name text)
returns uuid language plpgsql security definer set search_path = public as $$
declare target uuid;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  select id into target from crews where lower(name) = lower(trim(crew_name));
  if target is null then raise exception 'no crew named %', crew_name; end if;
  update players set crew_id = target where id = auth.uid();
  return target;
end;
$$;

-- ── leave_crew ───────────────────────────────────────────────────────────────
create or replace function leave_crew()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  update players set crew_id = null where id = auth.uid();
end;
$$;

-- ── crew_leaderboard: crews ranked by pooled area ────────────────────────────
create or replace function crew_leaderboard(lim int default 20)
returns table (id uuid, name text, color text, members int, total_area numeric)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.color,
         count(p.id)::int as members,
         coalesce(sum(p.total_area), 0) as total_area
  from crews c
  join players p on p.crew_id = c.id
  group by c.id, c.name, c.color
  order by total_area desc
  limit lim;
$$;
