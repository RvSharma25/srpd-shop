-- SRPD SHOP: delivery zone + charges
-- Run once on the existing Supabase database.

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS delivery_zone text;

ALTER TABLE public.orders
ADD COLUMN IF NOT EXISTS delivery_charge numeric(10,2) NOT NULL DEFAULT 0;

-- Optional safety constraint for the three supported delivery areas.
ALTER TABLE public.orders
DROP CONSTRAINT IF EXISTS orders_delivery_zone_check;

ALTER TABLE public.orders
ADD CONSTRAINT orders_delivery_zone_check
CHECK (delivery_zone IS NULL OR delivery_zone IN ('Bamial','Anial','Nearby villages'));

-- Backfill older orders as unknown/local so they remain visible.
UPDATE public.orders
SET delivery_zone = COALESCE(delivery_zone, 'Bamial')
WHERE delivery_zone IS NULL;
