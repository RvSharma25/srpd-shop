-- SRPD Shop migration: delivery details + multiple product photos
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS image_urls text[] NOT NULL DEFAULT '{}';

UPDATE public.products
SET image_urls = ARRAY[image_url]
WHERE image_url IS NOT NULL
  AND COALESCE(array_length(image_urls,1),0)=0;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS customer_name text,
  ADD COLUMN IF NOT EXISTS customer_phone text,
  ADD COLUMN IF NOT EXISTS delivery_address text,
  ADD COLUMN IF NOT EXISTS delivery_charge numeric(10,2) NOT NULL DEFAULT 0;

-- Customer may update/cancel only their own pending orders.
DROP POLICY IF EXISTS "customer cancel own pending" ON public.orders;
CREATE POLICY "customer cancel own pending"
ON public.orders FOR UPDATE
USING (auth.uid() = user_id AND status = 'pending')
WITH CHECK (auth.uid() = user_id AND status = 'cancelled');

-- Keep owner updates working.
DROP POLICY IF EXISTS "owner order update" ON public.orders;
CREATE POLICY "owner order update"
ON public.orders FOR UPDATE
USING (exists(select 1 from public.profiles where id=auth.uid() and role='owner'))
WITH CHECK (exists(select 1 from public.profiles where id=auth.uid() and role='owner'));

-- Notify the other party when an order is cancelled.
CREATE OR REPLACE FUNCTION public.notify_order_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    IF EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='owner') THEN
      INSERT INTO public.notifications(recipient_user_id,order_id,type,title,message)
      VALUES(NEW.user_id,NEW.id,'system','Order cancelled by shop','Order #'||left(NEW.id::text,8)||' has been cancelled by the shop.');
    ELSE
      INSERT INTO public.notifications(recipient_user_id,order_id,type,title,message)
      SELECT p.id,NEW.id,'system','Order cancelled by customer','Order #'||left(NEW.id::text,8)||' was cancelled by the customer.'
      FROM public.profiles p WHERE p.role='owner';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_cancelled_notify ON public.orders;
CREATE TRIGGER on_order_cancelled_notify
AFTER UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE PROCEDURE public.notify_order_cancelled();
