-- SRPD Shop 2.0 migration: account address book, completed orders, notification management.
-- Safe for the existing SRPD database. Run once in Supabase SQL Editor.

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (status IN ('pending','ready','completed','cancelled'));

CREATE TABLE IF NOT EXISTS public.customer_addresses(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  label text NOT NULL DEFAULT 'Home',
  full_name text NOT NULL,
  phone text NOT NULL,
  address_line_1 text NOT NULL,
  address_line_2 text,
  village text NOT NULL,
  district text NOT NULL,
  state text NOT NULL,
  pincode text NOT NULL,
  delivery_zone text NOT NULL CHECK(delivery_zone IN ('Bamial','Anial','Nearby villages','Other')),
  is_default boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS customer_addresses_user_idx ON public.customer_addresses(user_id, is_default DESC, created_at DESC);
ALTER TABLE public.customer_addresses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "address own read" ON public.customer_addresses;
DROP POLICY IF EXISTS "address own insert" ON public.customer_addresses;
DROP POLICY IF EXISTS "address own update" ON public.customer_addresses;
DROP POLICY IF EXISTS "address own delete" ON public.customer_addresses;
CREATE POLICY "address own read" ON public.customer_addresses FOR SELECT USING(auth.uid()=user_id);
CREATE POLICY "address own insert" ON public.customer_addresses FOR INSERT WITH CHECK(auth.uid()=user_id);
CREATE POLICY "address own update" ON public.customer_addresses FOR UPDATE USING(auth.uid()=user_id) WITH CHECK(auth.uid()=user_id);
CREATE POLICY "address own delete" ON public.customer_addresses FOR DELETE USING(auth.uid()=user_id);

DROP POLICY IF EXISTS "notifications own delete" ON public.notifications;
CREATE POLICY "notifications own delete" ON public.notifications FOR DELETE USING(auth.uid()=recipient_user_id);

DROP POLICY IF EXISTS "customer cancel own pending" ON public.orders;
CREATE POLICY "customer cancel own pending" ON public.orders
FOR UPDATE USING(auth.uid()=user_id AND status='pending')
WITH CHECK(auth.uid()=user_id AND status='cancelled');

DROP POLICY IF EXISTS "owner order update" ON public.orders;
CREATE POLICY "owner order update" ON public.orders
FOR UPDATE USING(EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='owner'))
WITH CHECK(EXISTS(SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='owner'));

CREATE OR REPLACE FUNCTION public.set_address_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at=now(); RETURN NEW; END; $$;
DROP TRIGGER IF EXISTS customer_addresses_updated_at ON public.customer_addresses;
CREATE TRIGGER customer_addresses_updated_at BEFORE UPDATE ON public.customer_addresses FOR EACH ROW EXECUTE PROCEDURE public.set_address_updated_at();
