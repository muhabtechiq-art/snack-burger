-- =============================================================================
-- Tighten business_days authenticated SELECT — tenant-scoped via profiles
-- Manual run only: Supabase Dashboard → SQL Editor
-- Branch intent: saas-v2
--
-- Prerequisites:
--   - public.business_days exists (business_days_schema.sql)
--   - public.orders_matches_admin_profile(text, text) exists (c01_orders_rls_migration.sql)
--
-- Does NOT change:
--   - business_days_public_read_open (anon/customer read open days)
--   - open_business_day / close_business_day RPCs
--   - INSERT / UPDATE / DELETE policies on business_days
--   - Any other table or RLS policy
-- =============================================================================

DROP POLICY IF EXISTS business_days_authenticated_read
  ON public.business_days;

DROP POLICY IF EXISTS business_days_authenticated_read_tenant
  ON public.business_days;

CREATE POLICY business_days_authenticated_read_tenant
  ON public.business_days
  FOR SELECT
  TO authenticated
  USING (
    public.orders_matches_admin_profile(restaurant_id, slug)
  );

COMMENT ON POLICY business_days_authenticated_read_tenant ON public.business_days IS
  'Authenticated admin reads business_days only for their profiles.restaurant_id tenant';

NOTIFY pgrst, 'reload schema';
