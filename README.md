# SRPD Shop

Dynamic e-commerce shop for SRPD using Next.js + Supabase.

## Features
- Three categories: Notebooks, Daily Utilities, Stationery
- Owner product management with image upload from gallery/camera
- Live products, stock status and pricing from Supabase
- Customer accounts with name, phone, email and password
- Cart and explicit **Yes / No order confirmation** before an order is created
- Customer and owner order history
- Click any order to open complete order details
- Customer and owner can cancel a pending order
- Owner can mark pending orders ready
- Realtime in-app notifications for new orders, ready orders and cancellations
- Optional browser notifications
- No SMS, WhatsApp or paid OTP dependency
- Supabase RLS and Realtime

## Existing Supabase project update
If the database is already in use, **do not rerun the full `supabase.sql` blindly**. Run:
`supabase_migration_orders_notifications.sql`
once in Supabase SQL Editor.

That migration adds cancellation fields/status, cancellation notifications, restricted customer cancellation permissions, and backfills product name/unit price for older order items.

## Deployment
1. Push the project to GitHub.
2. Import the repository into Vercel.
3. Add:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
4. Deploy.
5. For a new Supabase database, run `supabase.sql`.
6. For the already-configured SRPD database, run the migration file instead.
7. Create an account and set its profile role to `owner`:
   `update public.profiles set role='owner' where email='OWNER_EMAIL_HERE';`

Never commit `.env.local` or a Supabase service-role/secret key.
