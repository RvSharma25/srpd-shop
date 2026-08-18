# SRPD Shop

Dynamic e-commerce starter for SRPD Shop using Next.js + Supabase.

## Setup
1. Create a Supabase project.
2. Run `supabase.sql` in the Supabase SQL Editor.
3. Create the first account through the website, then change its profile role to `owner` using the SQL comment at the bottom of `supabase.sql`.
4. Copy `.env.example` to `.env.local` and add your Supabase URL and anon key.
5. Run `npm install` then `npm run dev`.

The app uses Supabase Auth, Postgres, Storage and realtime database events, so product/order changes are stored server-side and appear on other devices after they connect to the same deployed site.
