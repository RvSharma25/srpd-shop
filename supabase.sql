-- Run this once in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade,email text,role text not null default 'customer' check(role in ('customer','owner')));
create table if not exists public.products(id uuid primary key default gen_random_uuid(),name text not null,description text,price numeric(10,2) not null default 0,category text not null check(category in ('Notebooks','Daily Utilities','Stationery')),image_url text,in_stock boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.orders(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),status text not null default 'pending' check(status in ('pending','ready','completed')),total numeric(10,2) not null default 0,created_at timestamptz not null default now());
create table if not exists public.order_items(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.orders(id) on delete cascade,product_id uuid not null references public.products(id),quantity int not null check(quantity>0));
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into public.profiles(id,email) values(new.id,new.email); return new; end;$$;
drop trigger if exists on_auth_user_created on auth.users; create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
alter table public.profiles enable row level security; alter table public.products enable row level security; alter table public.orders enable row level security; alter table public.order_items enable row level security;
create policy "profiles self" on public.profiles for select using(auth.uid()=id);
create policy "products public read" on public.products for select using(true);
create policy "owner product insert" on public.products for insert with check(exists(select 1 from profiles where id=auth.uid() and role='owner'));
create policy "owner product delete" on public.products for delete using(exists(select 1 from profiles where id=auth.uid() and role='owner'));
create policy "owner product update" on public.products for update using(exists(select 1 from profiles where id=auth.uid() and role='owner'));
create policy "orders own insert" on public.orders for insert with check(auth.uid()=user_id);
create policy "orders read own or owner" on public.orders for select using(auth.uid()=user_id or exists(select 1 from profiles where id=auth.uid() and role='owner'));
create policy "owner order update" on public.orders for update using(exists(select 1 from profiles where id=auth.uid() and role='owner'));
create policy "items own insert" on public.order_items for insert with check(exists(select 1 from orders where id=order_id and user_id=auth.uid()));
create policy "items read own or owner" on public.order_items for select using(exists(select 1 from orders o where o.id=order_id and (o.user_id=auth.uid() or exists(select 1 from profiles where id=auth.uid() and role='owner'))));
-- Storage bucket for product photos
insert into storage.buckets(id,name,public) values('product-images','product-images',true) on conflict(id) do nothing;
create policy "public product image read" on storage.objects for select using(bucket_id='product-images');
create policy "owner product image upload" on storage.objects for insert with check(bucket_id='product-images' and exists(select 1 from profiles where id=auth.uid() and role='owner'));
create policy "owner product image delete" on storage.objects for delete using(bucket_id='product-images' and exists(select 1 from profiles where id=auth.uid() and role='owner'));
-- After creating the owner account, run: update public.profiles set role='owner' where email='OWNER_EMAIL_HERE';
