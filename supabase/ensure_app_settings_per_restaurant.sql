-- Ensure one app_settings row per restaurant (SaaS v2)
-- Manual run only: Supabase Dashboard → SQL Editor
--
-- Safe / idempotent:
-- - INSERT ... SELECT ... ON CONFLICT DO NOTHING
-- - Does not UPDATE any existing row
-- - Does not modify id = 'global'
-- - Does not touch RLS
--
-- app_settings.id matches Flutter routing/settings scope:
--   normalizeRestaurantSlug(slug) = trim → lower → '-' to '_'
-- (see lib/core/utils/restaurant_slug_utils.dart and AppSettingsNotifier.bindRestaurant)
--
-- Prerequisites:
-- - public.restaurants with non-null unique slug
-- - public.app_settings (app_settings_schema.sql)
-- - Optional: daily_sound_migration.sql / business_day_closing_time_migration.sql
--   (new rows pick up column defaults when those migrations are applied)
--
-- New rows only:
-- - maintenance_mode = false
-- - daily_sound_* left to table defaults (disabled / null as defined by schema)

INSERT INTO public.app_settings (id, maintenance_mode)
SELECT
  lower(replace(btrim(r.slug), '-', '_')) AS id,
  false AS maintenance_mode
FROM public.restaurants AS r
WHERE r.slug IS NOT NULL
  AND btrim(r.slug) <> ''
  AND lower(replace(btrim(r.slug), '-', '_')) <> 'global'
ON CONFLICT (id) DO NOTHING;
