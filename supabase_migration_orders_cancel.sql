-- SRPD Shop: order workflow migration for an existing database
-- Adds cancellation + owner order log support. Safe to run once.

ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_status_check;
ALTER TABLE public.orders ADD CONSTRAINT orders_status_check CHECK (status IN ('pending','ready','completed','cancelled'));

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancelled_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS cancellation_reason text;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type IN ('new_order','order_ready','order_cancelled','system'));

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customer cancel own pending" ON public.orders;
CREATE POLICY "customer cancel own pending" ON public.orders
FOR UPDATE
USING (auth.uid() = user_id AND status = 'pending')
WITH CHECK (auth.uid() = user_id AND status = 'cancelled');

-- Owner update policy remains the authority for marking ready/cancelled.
DROP POLICY IF EXISTS "owner order update" ON public.orders;
CREATE POLICY "owner order update" ON public.orders
FOR UPDATE
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='owner'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role='owner'));

CREATE OR REPLACE FUNCTION public.notify_order_cancelled()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public
AS $$
BEGIN
  IF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM 'cancelled' THEN
    IF NEW.cancelled_by = NEW.user_id THEN
      INSERT INTO public.notifications(recipient_user_id,order_id,type,title,message)
      SELECT p.id,NEW.id,'order_cancelled','Order cancelled by customer',
             COALESCE(NULLIF((SELECT full_name FROM public.profiles WHERE id=NEW.user_id),''),'Customer') || ' cancelled order #' || left(NEW.id::text,8)
      FROM public.profiles p WHERE p.role='owner';
    ELSE
      INSERT INTO public.notifications(recipient_user_id,order_id,type,title,message)
      VALUES(NEW.user_id,NEW.id,'order_cancelled','Order cancelled by shop','Your order #' || left(NEW.id::text,8) || ' has been cancelled by the shop.');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_order_cancelled_notify ON public.orders;
CREATE TRIGGER on_order_cancelled_notify
AFTER UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE PROCEDURE public.notify_order_cancelled();

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='orders') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
  END IF;
END $$;
