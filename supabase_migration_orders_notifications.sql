-- SRPD SHOP - ORDER CONFIRMATION + CANCELLATION MIGRATION
-- Run this ONCE in an already-configured SRPD Shop Supabase project.
-- It preserves existing products, users and orders.

alter table public.orders add column if not exists cancelled_at timestamptz;
alter table public.orders add column if not exists cancelled_by text;

alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check
  check(status in ('pending','ready','completed','cancelled'));

alter table public.orders drop constraint if exists orders_cancelled_by_check;
alter table public.orders add constraint orders_cancelled_by_check
  check(cancelled_by is null or cancelled_by in ('customer','owner'));

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check(type in ('new_order','order_ready','order_cancelled','system'));

-- Fill names/prices for older orders.
update public.order_items oi
set product_name=p.name,
    unit_price=p.price
from public.products p
where oi.product_id=p.id
  and (oi.product_name is null or oi.unit_price is null);

-- Cancellation notifications.
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
        new.user_id,new.id,'order_cancelled',
        'Order cancelled by shop',
        'Your order #' || left(new.id::text,8) || ' has been cancelled by the shop.'
      );
    elsif new.cancelled_by='customer' then
      insert into public.notifications(recipient_user_id,order_id,type,title,message)
      select p.id,new.id,'order_cancelled',
             'Order cancelled by customer',
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

-- Replace order-update policies with restricted transitions.
drop policy if exists "owner order update" on public.orders;
drop policy if exists "customer cancel own pending order" on public.orders;

create policy "owner order update"
on public.orders for update
using(exists(select 1 from public.profiles where id=auth.uid() and role='owner'))
with check(
  exists(select 1 from public.profiles where id=auth.uid() and role='owner')
  and status in ('pending','ready','cancelled','completed')
  and (cancelled_by is null or cancelled_by='owner')
);

create policy "customer cancel own pending order"
on public.orders for update
using(auth.uid()=user_id and status='pending')
with check(
  auth.uid()=user_id
  and status='cancelled'
  and cancelled_by='customer'
);

-- Ensure notifications and orders are in Supabase Realtime.
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
