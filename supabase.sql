-- SRPD SHOP - COMPLETE DATABASE SETUP
-- Safe to run on a new database. For an already-used database, run
-- supabase_migration_orders_notifications.sql instead.

create extension if not exists pgcrypto;

create table if not exists public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  role text not null default 'customer' check(role in ('customer','owner'))
);

alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists phone text;

create table if not exists public.products(
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  price numeric(10,2) not null default 0,
  category text not null check(category in ('Notebooks','Daily Utilities','Stationery')),
  image_url text,
  in_stock boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  status text not null default 'pending',
  total numeric(10,2) not null default 0,
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by text
);

alter table public.orders add column if not exists cancelled_at timestamptz;
alter table public.orders add column if not exists cancelled_by text;

alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check check(status in ('pending','ready','completed','cancelled'));
alter table public.orders drop constraint if exists orders_cancelled_by_check;
alter table public.orders add constraint orders_cancelled_by_check check(cancelled_by is null or cancelled_by in ('customer','owner'));

create table if not exists public.order_items(
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity int not null check(quantity>0),
  unit_price numeric(10,2),
  product_name text
);

alter table public.order_items add column if not exists unit_price numeric(10,2);
alter table public.order_items add column if not exists product_name text;

create table if not exists public.notifications(
  id uuid primary key default gen_random_uuid(),
  recipient_user_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete cascade,
  type text not null,
  title text not null,
  message text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check check(type in ('new_order','order_ready','order_cancelled','system'));

create index if not exists notifications_recipient_created_idx
on public.notifications(recipient_user_id, created_at desc);

-- Create/update profile when a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.profiles(id,email,full_name,phone)
  values(
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    coalesce(new.raw_user_meta_data->>'phone','')
  )
  on conflict(id) do update set
    email=excluded.email,
    full_name=coalesce(nullif(excluded.full_name,''),public.profiles.full_name),
    phone=coalesce(nullif(excluded.phone,''),public.profiles.phone);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- New order -> notify every owner.
create or replace function public.notify_new_order()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  insert into public.notifications(recipient_user_id,order_id,type,title,message)
  select p.id,new.id,'new_order','New order received',
         'Order #' || left(new.id::text,8) ||
         ' has been placed for ₹' || to_char(new.total,'FM999999990.00')
  from public.profiles p
  where p.role='owner';
  return new;
end;
$$;

drop trigger if exists on_order_created_notify on public.orders;
create trigger on_order_created_notify
after insert on public.orders
for each row execute procedure public.notify_new_order();

-- Ready -> notify customer.
create or replace function public.notify_order_ready()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status='ready' and old.status is distinct from 'ready' then
    insert into public.notifications(recipient_user_id,order_id,type,title,message)
    values(
      new.user_id,
      new.id,
      'order_ready',
      'Your order is ready',
      'Order #' || left(new.id::text,8) || ' is ready for collection.'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists on_order_ready_notify on public.orders;
create trigger on_order_ready_notify
after update of status on public.orders
for each row execute procedure public.notify_order_ready();

-- Cancellation -> notify the other party.
create or replace function public.notify_order_cancelled()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status='cancelled' and old.status is distinct from 'cancelled' then
    if new.cancelled_by='owner' then
      insert into public.notifications(recipient_user_id,order_id,type,title,message)
      values(
        new.user_id,
        new.id,
        'order_cancelled',
        'Order cancelled by shop',
        'Your order #' || left(new.id::text,8) || ' has been cancelled by the shop.'
      );
    elsif new.cancelled_by='customer' then
      insert into public.notifications(recipient_user_id,order_id,type,title,message)
      select p.id,new.id,'order_cancelled','Order cancelled by customer',
             'Order #' || left(new.id::text,8) || ' was cancelled by the customer.'
      from public.profiles p
      where p.role='owner';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists on_order_cancelled_notify on public.orders;
create trigger on_order_cancelled_notify
after update of status on public.orders
for each row execute procedure public.notify_order_cancelled();

-- RLS
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.notifications enable row level security;

do $$ declare r record; begin
  for r in
    select schemaname,tablename,policyname
    from pg_policies
    where (schemaname='public' and tablename in ('profiles','products','orders','order_items','notifications'))
       or (schemaname='storage' and tablename='objects' and policyname ilike '%product%')
  loop
    execute format('drop policy if exists %I on %I.%I',r.policyname,r.schemaname,r.tablename);
  end loop;
end $$;

create policy "profiles self"
on public.profiles for select
using(auth.uid()=id or exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='owner'));

create policy "profiles self update"
on public.profiles for update
using(auth.uid()=id)
with check(auth.uid()=id);

create policy "products public read"
on public.products for select using(true);

create policy "owner product insert"
on public.products for insert
with check(exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

create policy "owner product delete"
on public.products for delete
using(exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

create policy "owner product update"
on public.products for update
using(exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

create policy "orders own insert"
on public.orders for insert
with check(auth.uid()=user_id);

create policy "orders read own or owner"
on public.orders for select
using(auth.uid()=user_id or exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

-- Owner may transition pending orders to ready or cancelled.
create policy "owner order update"
on public.orders for update
using(exists(select 1 from public.profiles where id=auth.uid() and role='owner'))
with check(
  exists(select 1 from public.profiles where id=auth.uid() and role='owner')
  and status in ('pending','ready','cancelled','completed')
  and (cancelled_by is null or cancelled_by='owner')
);

-- Customer may ONLY cancel their own pending order.
create policy "customer cancel own pending order"
on public.orders for update
using(auth.uid()=user_id and status='pending')
with check(
  auth.uid()=user_id
  and status='cancelled'
  and cancelled_by='customer'
);

create policy "items own insert"
on public.order_items for insert
with check(exists(select 1 from public.orders where id=order_id and user_id=auth.uid()));

create policy "items read own or owner"
on public.order_items for select
using(exists(
  select 1 from public.orders o
  where o.id=order_id
    and (o.user_id=auth.uid() or exists(select 1 from public.profiles where id=auth.uid() and role='owner'))
));

create policy "notifications own read"
on public.notifications for select
using(auth.uid()=recipient_user_id);

create policy "notifications own update"
on public.notifications for update
using(auth.uid()=recipient_user_id)
with check(auth.uid()=recipient_user_id);

insert into storage.buckets(id,name,public)
values('product-images','product-images',true)
on conflict(id) do nothing;

create policy "public product image read"
on storage.objects for select using(bucket_id='product-images');

create policy "owner product image upload"
on storage.objects for insert
with check(bucket_id='product-images' and exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

create policy "owner product image delete"
on storage.objects for delete
using(bucket_id='product-images' and exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='orders'
  ) then
    alter publication supabase_realtime add table public.orders;
  end if;
end $$;

-- After creating the owner account:
-- update public.profiles set role='owner' where email='OWNER_EMAIL_HERE';
