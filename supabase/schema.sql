-- Couples MVP schema + RLS for Supabase
-- Lean by design: anonymous device auth + pairing code + latest-moment sharing.

create extension if not exists "pgcrypto";

-- Keep app-level user records lightweight and tied to auth users
-- (for this flow, each device uses anonymous auth).
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
created_at timestamptz not null default now()
);

create table if not exists public.pairs (
  id uuid primary key default gen_random_uuid(),
  user1_id uuid not null references public.users(id) on delete cascade,
  user2_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint pairs_distinct_users check (user1_id <> user2_id)
);

create table if not exists public.moments (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  image_url text not null,
  text varchar(200) not null,
  created_at timestamptz not null default now()
);

-- Invite code table for strict 1:1 linking.
create table if not exists public.invite_codes (
  code text primary key,
  created_by uuid not null references public.users(id) on delete cascade,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists moments_pair_created_at_idx on public.moments(pair_id, created_at desc);
create index if not exists invite_codes_created_by_idx on public.invite_codes(created_by);
create unique index if not exists pairs_unique_ordered_idx
on public.pairs ((least(user1_id, user2_id)), (greatest(user1_id, user2_id)));

-- Guarantees each user can belong to at most one pair total.
create or replace function public.assert_user_has_no_pair(user_id uuid)
returns void
language plpgsql
as $$
begin
  if exists (
    select 1 from public.pairs p
    where p.user1_id = user_id or p.user2_id = user_id
  ) then
    raise exception 'User already belongs to a pair';
  end if;
end;
$$;

create or replace function public.enforce_pair_membership_uniqueness()
returns trigger
language plpgsql
as $$
begin
  perform public.assert_user_has_no_pair(new.user1_id);
  perform public.assert_user_has_no_pair(new.user2_id);
  return new;
end;
$$;

drop trigger if exists trg_enforce_pair_membership_uniqueness on public.pairs;
create trigger trg_enforce_pair_membership_uniqueness
before insert on public.pairs
for each row execute function public.enforce_pair_membership_uniqueness();

create or replace function public.is_in_pair(pair_row public.pairs, uid uuid)
returns boolean
language sql
stable
as $$
  select pair_row.user1_id = uid or pair_row.user2_id = uid;
$$;

create or replace function public.get_my_pair_id()
returns uuid
language sql
stable
as $$
  select p.id
  from public.pairs p
  where p.user1_id = auth.uid() or p.user2_id = auth.uid()
  limit 1;
$$;

create or replace function public.user_in_pair(pair uuid, uid uuid)
returns boolean
language sql
stable
as $$
  select exists (
    select 1 from public.pairs p
    where p.id = pair and (p.user1_id = uid or p.user2_id = uid)
  );
$$;

-- Generates a short invite code for current user.
create or replace function public.create_pair(invite_ttl_minutes integer default 30)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  new_code text;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  perform public.assert_user_has_no_pair(me);

  -- Invalidate previous active invites from this user.
  update public.invite_codes
  set consumed_at = now()
  where created_by = me and consumed_at is null and expires_at > now();

  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.invite_codes(code, created_by, expires_at)
  values (new_code, me, now() + make_interval(mins => invite_ttl_minutes));

  return new_code;
end;
$$;

-- User joins partner by invite code and pair is created.
create or replace function public.join_pair(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  host uuid;
  pair_id uuid;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  perform public.assert_user_has_no_pair(me);

  select created_by into host
  from public.invite_codes
  where code = upper(invite_code)
    and consumed_at is null
    and expires_at > now()
  for update;

  if host is null then
    raise exception 'Invalid or expired invite code';
  end if;

  if host = me then
    raise exception 'Cannot join your own invite code';
  end if;

  perform public.assert_user_has_no_pair(host);

  insert into public.pairs(user1_id, user2_id)
  values (host, me)
  returning id into pair_id;

  update public.invite_codes
  set consumed_at = now(),
      consumed_by = me
  where code = upper(invite_code);

  return pair_id;
end;
$$;

create or replace function public.unlink_pair()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.pairs p
  where p.user1_id = auth.uid() or p.user2_id = auth.uid();
end;
$$;

create or replace function public.upload_moment(image_path text, message text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  pair_id uuid;
  moment_id uuid;
begin
  if me is null then
    raise exception 'Not authenticated';
  end if;

  if length(trim(message)) = 0 or length(message) > 200 then
    raise exception 'Message must be between 1 and 200 characters';
  end if;

  select public.get_my_pair_id() into pair_id;
  if pair_id is null then
    raise exception 'User is not paired';
  end if;

  insert into public.moments(pair_id, sender_id, image_url, text)
  values (pair_id, me, image_path, message)
  returning id into moment_id;

  return moment_id;
end;
$$;

create or replace function public.fetch_latest_moment(target_pair_id uuid)
returns table (
  id uuid,
  pair_id uuid,
  sender_id uuid,
  image_url text,
  text varchar(200),
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select m.id, m.pair_id, m.sender_id, m.image_url, m.text, m.created_at
  from public.moments m
  where m.pair_id = target_pair_id
    and m.sender_id <> auth.uid()
    and public.user_in_pair(target_pair_id, auth.uid())
  order by m.created_at desc
  limit 1;
$$;

alter table public.users enable row level security;
alter table public.pairs enable row level security;
alter table public.moments enable row level security;
alter table public.invite_codes enable row level security;

-- USERS RLS
drop policy if exists "users_select_self" on public.users;
create policy "users_select_self"
on public.users for select
using (id = auth.uid());

drop policy if exists "users_insert_self" on public.users;
create policy "users_insert_self"
on public.users for insert
with check (id = auth.uid());

drop policy if exists "users_update_self" on public.users;
create policy "users_update_self"
on public.users for update
using (id = auth.uid());

-- PAIRS RLS
drop policy if exists "pairs_select_own" on public.pairs;
create policy "pairs_select_own"
on public.pairs for select
using (public.is_in_pair(pairs, auth.uid()));

drop policy if exists "pairs_delete_own" on public.pairs;
create policy "pairs_delete_own"
on public.pairs for delete
using (public.is_in_pair(pairs, auth.uid()));

-- MOMENTS RLS
drop policy if exists "moments_select_own_pair" on public.moments;
create policy "moments_select_own_pair"
on public.moments for select
using (
  exists (
    select 1 from public.pairs p
    where p.id = moments.pair_id
      and public.is_in_pair(p, auth.uid())
  )
);

drop policy if exists "moments_insert_own_pair_only" on public.moments;
create policy "moments_insert_own_pair_only"
on public.moments for insert
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.pairs p
    where p.id = moments.pair_id
      and public.is_in_pair(p, auth.uid())
  )
);

-- INVITE CODES RLS
drop policy if exists "invite_codes_select_self" on public.invite_codes;
create policy "invite_codes_select_self"
on public.invite_codes for select
using (created_by = auth.uid() or consumed_by = auth.uid());

drop policy if exists "invite_codes_insert_self" on public.invite_codes;
create policy "invite_codes_insert_self"
on public.invite_codes for insert
with check (created_by = auth.uid());

-- Storage RLS for bucket "moments" with object path format:
-- "<pair_id>/<random>.jpg"
insert into storage.buckets (id, name, public)
values ('moments', 'moments', false)
on conflict (id) do nothing;

drop policy if exists "moments_storage_insert_own_pair" on storage.objects;
create policy "moments_storage_insert_own_pair"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'moments'
  and public.user_in_pair((split_part(name, '/', 1))::uuid, auth.uid())
);

drop policy if exists "moments_storage_select_own_pair" on storage.objects;
create policy "moments_storage_select_own_pair"
on storage.objects for select
to authenticated
using (
  bucket_id = 'moments'
  and public.user_in_pair((split_part(name, '/', 1))::uuid, auth.uid())
);
