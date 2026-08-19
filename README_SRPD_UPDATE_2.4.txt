SRPD Shop — Update 2.4

This is a complete project ZIP based on the uploaded srpd-shop-main project.

Included fixes:
1. Mobile notification panel is constrained to the viewport and no longer overflows left/right.
2. Mobile owner panel is centered with safe viewport width.
3. Delivery checkout "Continue to confirmation" now correctly enables when the minimum order is met:
   - Bamial: free delivery, minimum ₹100
   - Anial: free delivery, minimum ₹100
   - Nearby villages: ₹50 delivery, minimum ₹300
   - Other: not deliverable
4. Mobile floating cart bar appears whenever the cart has items, so customers do not need to scroll back to the top.
5. Product-card slideshow/layout CSS is explicitly imported from app/layout.tsx.
6. Signup fallback attempts automatic login when email confirmation is disabled and Supabase returns no session.
7. Existing Supabase data, products, orders and images are not deleted or reset by this update.

Deployment:
- Upload/replace the complete project files in GitHub.
- Vercel should redeploy automatically.
- Keep Supabase Email Confirm disabled if you want signup without email verification.
- No SQL migration is required for the UI/checkout fixes in this update.

Important:
- Do not replace your Supabase project or database.
- Keep your Vercel environment variables NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_ANON_KEY unchanged.
