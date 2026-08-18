# SRPD Shop 2.0

Next.js + Supabase dynamic e-commerce shop for SRPD Shop.

## What's included
- Customer account with mandatory name, phone, email and password at signup
- Multiple saved delivery addresses
- Delivery zones: Bamial, Anial, Nearby villages, Other/not deliverable
- Free delivery in Bamial/Anial on ₹100+ orders
- ₹50 delivery in nearby villages on ₹300+ orders
- Dedicated cart with quantity controls and item removal
- Checkout → delivery → confirmation → order placement
- Owner product add/edit/remove, multiple photos and camera/gallery upload
- Owner Orders: Pending, Ready, Completed, Cancelled
- Date-grouped order history, search and date filters
- Realtime notifications with mark-read, delete and clear-all
- Mobile hamburger navigation and responsive two-column product grid

## Deployment
1. Run `supabase_migration_v2.sql` once in the existing Supabase project.
2. Upload the project files to GitHub (never upload `.env.local`).
3. Vercel will redeploy automatically.
4. Ensure `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` are configured in Vercel.

This update is designed for the existing SRPD Shop database; do not rerun the original `supabase.sql` on the live database.
