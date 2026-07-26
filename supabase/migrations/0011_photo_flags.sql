-- 0011_photo_flags.sql — Phase 8 layer 7: photo flags (leave a photo on the map).
-- Run AFTER 0010. Creates a public storage bucket for flag images, a table of
-- flags, and a nearby-flags query.

-- Public storage bucket for flag photos.
insert into storage.buckets (id, name, public)
values ('flags', 'flags', true)
on conflict (id) do nothing;

-- Anyone signed in can upload into the flags bucket; reads are public.
drop policy if exists "flags upload by authenticated" on storage.objects;
create policy "flags upload by authenticated"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'flags');

create table if not exists photo_flags (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references players (id) on delete cascade,
  lng        double precision not null,
  lat        double precision not null,
  url        text not null,
  caption    text,
  created_at timestamptz not null default now()
);

alter table photo_flags enable row level security;
create policy "flags readable by all" on photo_flags for select using (true);
create policy "flags insert by owner" on photo_flags for insert
  with check (auth.uid() = owner_id);
create policy "flags delete by owner" on photo_flags for delete
  using (auth.uid() = owner_id);

-- ── flags_near: photo flags within radius_m of a point ───────────────────────
-- NB: params are prefixed p_ to avoid colliding with the output columns
-- lng/lat (a collision silently broke the distance filter).
drop function if exists flags_near(double precision, double precision, double precision);
create function flags_near(p_lng double precision, p_lat double precision, radius_m double precision)
returns table (id uuid, owner_id uuid, lng double precision, lat double precision, url text, caption text)
language sql stable security definer set search_path = public as $$
  select f.id, f.owner_id, f.lng, f.lat, f.url, f.caption
  from photo_flags f
  where st_dwithin(
    st_setsrid(st_makepoint(f.lng, f.lat), 4326)::geography,
    st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
    radius_m
  );
$$;
