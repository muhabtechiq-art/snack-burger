-- Dev / SaaS trial: create second restaurant "Burger Lab"
-- Manual run only: Supabase Dashboard → SQL Editor
--
-- Safe / idempotent for restaurants + app_settings:
-- - INSERT ... ON CONFLICT DO NOTHING
-- - Does not UPDATE existing rows
-- - Does not create auth.users
-- - Does not touch RLS
-- - Does not use snack_burger
--
-- After this script:
-- 1) Create an Auth user in Supabase Dashboard (Authentication → Users).
-- 2) Run the commented profiles INSERT below with that user's UUID.
--
-- Test URLs (do not use "/"):
--   Customer: /#/burger_lab
--   Admin:    /#/burger_lab/admin/login

-- ---------------------------------------------------------------------------
-- 1) restaurants
-- Required (restaurants_table_schema.sql): id, slug, name
-- Optional defaults: primary_color, accent_color, order_routing_mode, is_active
-- restaurant_uuid: from restaurants_restaurant_uuid_migration.sql (NOT NULL when applied).
--   If that column does not exist yet, remove restaurant_uuid from the lists below.
-- ---------------------------------------------------------------------------
INSERT INTO public.restaurants (
  id,
  slug,
  name,
  primary_color,
  accent_color,
  order_routing_mode,
  is_active,
  restaurant_uuid
) VALUES (
  'burger_lab',
  'burger_lab',
  'Burger Lab',
  '#1B5E20',
  '#FFC107',
  'whatsapp',
  true,
  gen_random_uuid()
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2) app_settings (scoped by slug — matches Flutter bindRestaurant / submitOrder)
-- maintenance_mode = false for new row only; never updates existing rows.
-- daily_sound_* use table defaults when those columns exist.
-- ---------------------------------------------------------------------------
INSERT INTO public.app_settings (
  id,
  maintenance_mode
) VALUES (
  'burger_lab',
  false
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3) profiles (ADMIN LINK) — DO NOT RUN AS-IS
-- Create the Auth user first in the Dashboard, then replace <AUTH_USER_UUID>
-- with that user's UUID and run only this block.
--
-- profiles.id           = auth.users.id
-- profiles.restaurant_id = route slug ('burger_lab') — must match URL /#/burger_lab
-- profiles.role         = 'admin' (any non-empty role is accepted by Flutter)
-- ---------------------------------------------------------------------------
-- INSERT INTO public.profiles (
--   id,
--   restaurant_id,
--   role
-- ) VALUES (
--   '<AUTH_USER_UUID>',
--   'burger_lab',
--   'admin'
-- )
-- ON CONFLICT (id) DO NOTHING;
