-- 0025_friends.sql — Referrals + friends. Run AFTER 0024.
--
-- Every player has a short share code. Redeeming a friend's code once pays
-- both of you coins (classic growth loop). The same code adds someone as a
-- friend, so you can see each other on a friends board.

alter table players add column if not exists referral_code text unique;
alter table players add column if not exists referred_by   uuid references players (id) on delete set null;

create table if not exists friendships (
  player_id  uuid not null references players (id) on delete cascade,
  friend_id  uuid not null references players (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (player_id, friend_id)
);
alter table friendships enable row level security;
create policy "friendships readable by owner" on friendships
  for select using (auth.uid() = player_id);

-- ── my_referral_code: your code, generated on first request ─────────────────
create or replace function my_referral_code()
returns text language plpgsql security definer set search_path = public as $$
declare code text;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  select referral_code into code from players where id = auth.uid();
  if code is null then
    code := upper(substr(md5(auth.uid()::text || clock_timestamp()::text), 1, 6));
    update players set referral_code = code where id = auth.uid();
  end if;
  return code;
end;
$$;

-- ── redeem_referral: enter a friend's code once for a mutual coin bonus ──────
create or replace function redeem_referral(friend_code text)
returns int language plpgsql security definer set search_path = public as $$
declare referrer uuid; already uuid;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select referred_by into already from players where id = auth.uid();
  if already is not null then raise exception 'you already redeemed a code'; end if;

  select id into referrer from players
   where referral_code = upper(trim(friend_code));
  if referrer is null then raise exception 'invalid code'; end if;
  if referrer = auth.uid() then raise exception 'you cannot refer yourself'; end if;

  update players set referred_by = referrer where id = auth.uid();
  update players set coins = coins + 50  where id = auth.uid(); -- new player
  update players set coins = coins + 100 where id = referrer;   -- referrer

  -- Redeeming also makes you friends both ways.
  insert into friendships (player_id, friend_id) values (auth.uid(), referrer)
    on conflict do nothing;
  insert into friendships (player_id, friend_id) values (referrer, auth.uid())
    on conflict do nothing;

  return (select coins from players where id = auth.uid());
end;
$$;

-- ── add_friend: follow a player by their code (no coin bonus) ────────────────
create or replace function add_friend(friend_code text)
returns void language plpgsql security definer set search_path = public as $$
declare target uuid;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  select id into target from players where referral_code = upper(trim(friend_code));
  if target is null then raise exception 'invalid code'; end if;
  if target = auth.uid() then raise exception 'that is your own code'; end if;

  insert into friendships (player_id, friend_id) values (auth.uid(), target)
    on conflict do nothing;
  insert into friendships (player_id, friend_id) values (target, auth.uid())
    on conflict do nothing;
end;
$$;

-- ── friends_board: your friends ranked by this week's area ──────────────────
create or replace function friends_board()
returns table (fid uuid, fname text, fcolor text, favatar text, warea numeric)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  return query
    select p.id, p.display_name, p.color, p.avatar,
           coalesce(s.weekly_area, 0)
    from friendships f
    join players p on p.id = f.friend_id
    left join player_league_stats s on s.player_id = f.friend_id
    where f.player_id = auth.uid()
    order by coalesce(s.weekly_area, 0) desc;
end;
$$;
