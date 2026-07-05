-- =============================================================================
-- Fix orders SELECT policy — use orders_matches_admin_profile (not catalog)
-- Manual run only: Supabase Dashboard → SQL Editor
-- Branch intent: saas-v2
--
-- Live DB drift: some databases use
--   catalog_matches_admin_profile(COALESCE(restaurant_id::text, slug))
-- which fails when orders.restaurant_id is a UUID (Phase 1).
--
-- Repo source of truth: c01_orders_rls_migration.sql
--
-- Prerequisites:
--   public.orders_matches_admin_profile(text, text) (c01_orders_rls_migration.sql)
--
-- Does NOT change:
--   - orders_c01_select_anon_interim
--   - orders_c01_update_authenticated_admin
--   - INSERT / DELETE policies
--   - Any RPC
-- =============================================================================

DROP POLICY IF EXISTS orders_c01_select_authenticated_tenant
  ON public.orders;

CREATE POLICY orders_c01_select_authenticated_tenant
  ON public.orders
  FOR SELECT
  TO authenticated
  USING (
    public.orders_matches_admin_profile(
      restaurant_id::text,
      slug
    )
  );

NOTIFY pgrst, 'reload schema';
