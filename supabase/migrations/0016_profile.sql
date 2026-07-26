-- 0016_profile.sql — Editable player profiles: name, colour and avatar.
-- Run AFTER 0015. Until now every player was an anonymous install with an
-- auto-assigned colour and no name.

alter table players add column if not exists avatar text;

-- ── update_profile: set name / colour / avatar with validation ───────────────
-- Validated server-side so a crafted client can't inject junk into the
-- leaderboard other players see.
create or replace function update_profile(
  new_name   text,
  new_color  text,
  new_avatar text
)
returns void language plpgsql security definer set search_path = public as $$
declare
  clean_name text := trim(new_name);
  palette text[] := array['#E69F00','#56B4E9','#009E73','#F0E442',
                          '#0072B2','#D55E00','#CC79A7'];
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  if length(clean_name) < 2 or length(clean_name) > 20 then
    raise exception 'name must be 2-20 characters';
  end if;

  -- Restrict to the colourblind-safe palette (CLAUDE.md Part 5).
  if not (new_color = any(palette)) then
    raise exception 'colour must be one of the ownership palette';
  end if;

  -- Avatar is a single emoji; keep it short so it can't be abused as a label.
  if new_avatar is not null and length(new_avatar) > 8 then
    raise exception 'avatar too long';
  end if;

  update players
     set display_name = clean_name,
         color        = new_color,
         avatar       = new_avatar
   where id = auth.uid();
end;
$$;
