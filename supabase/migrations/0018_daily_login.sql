-- 0018_daily_login.sql — 7-day escalating login rewards. Run AFTER 0017.
--
-- Open the game on consecutive days to walk up a reward ladder; day 7 pays out
-- big and also grants a perk, then the cycle restarts. Missing a day resets you
-- to day 1, which is what makes the streak feel worth protecting.

alter table players add column if not exists login_day    int not null default 0;
alter table players add column if not exists last_login_at date;

-- Reward for a given day of the cycle.
create or replace function login_reward_coins(day int)
returns int language sql immutable as $$
  select case day
           when 1 then 10  when 2 then 15  when 3 then 25
           when 4 then 40  when 5 then 60  when 6 then 80
           when 7 then 150 else 10
         end;
$$;

-- ── daily_login_status: where you are in the cycle and can you claim now ─────
create or replace function daily_login_status()
returns table (day int, claimable boolean, next_coins int)
language plpgsql stable security definer set search_path = public as $$
declare last date; cur int; upcoming int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select last_login_at, login_day into last, cur from players where id = auth.uid();
  cur := coalesce(cur, 0);

  -- Work out which day they'd be claiming if they claimed right now.
  if last = current_date then
    upcoming := cur;                       -- already claimed today
  elsif last = current_date - 1 then
    upcoming := case when cur >= 7 then 1 else cur + 1 end;
  else
    upcoming := 1;                         -- first time, or streak broken
  end if;

  return query select upcoming,
                      (last is distinct from current_date),
                      login_reward_coins(upcoming);
end;
$$;

-- ── claim_login_reward: pay out today's reward ──────────────────────────────
create or replace function claim_login_reward()
returns table (day int, coins_awarded int, perk text)
language plpgsql security definer set search_path = public as $$
declare
  last date; cur int; new_day int; reward int; bonus text := null;
  perks text[] := array['sprint','shield','wide_brush','recon'];
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select last_login_at, login_day into last, cur from players where id = auth.uid();
  cur := coalesce(cur, 0);

  if last = current_date then
    raise exception 'daily reward already claimed today';
  elsif last = current_date - 1 then
    new_day := case when cur >= 7 then 1 else cur + 1 end;
  else
    new_day := 1;
  end if;

  reward := login_reward_coins(new_day);

  -- Day 7 also drops a perk, so the ladder has a real prize at the top.
  if new_day = 7 then
    bonus := perks[1 + floor(random() * 4)::int];
    insert into player_perks (player_id, perk, qty) values (auth.uid(), bonus, 1)
      on conflict (player_id, perk) do update set qty = player_perks.qty + 1;
  end if;

  update players
     set coins         = coins + reward,
         login_day     = new_day,
         last_login_at = current_date
   where id = auth.uid();

  return query select new_day, reward, bonus;
end;
$$;
